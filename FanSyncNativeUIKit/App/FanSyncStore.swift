import Foundation
import UIKit

final class FanSyncStore {
    enum SessionState: Equatable {
        case loggedOut
        case loggingIn
        case connecting
        case ready
        case error(String)
    }

    private(set) var state: SessionState = .loggedOut {
        didSet { stateDidChange.notify(state) }
    }
    private(set) var devices: [FanDevice] = [] {
        didSet { devicesDidChange.notify(devices) }
    }
    private(set) var accountEmail: String?

    let stateDidChange = ObserverList<SessionState>()
    let devicesDidChange = ObserverList<[FanDevice]>()

    private let http = FanSyncHTTPClient()
    private var ws: FanSyncWebSocket?
    private var token: String?
    private let groupStore: DeviceGroupStore
    // Keyed by "<deviceId>:<fieldCode>" — debounces slider-driven set requests (fan
    // speed, light brightness) so dragging doesn't flood the socket with one request
    // per pixel of movement. Confirmed via live testing: sending ~80 rapid H0C sets
    // while dragging caused the server/device to apply an earlier mid-drag value
    // instead of the final one, desyncing our UI (showed 100%) from the device's real
    // state (actually settled at 50%, matching the official app) — a race condition
    // from out-of-order command processing, not a bug in request correctness. Only the
    // FINAL value after a drag pause needs to reach the server.
    private var pendingSetWork: [String: DispatchWorkItem] = [:]

    init(groupStore: DeviceGroupStore) {
        self.groupStore = groupStore
        // iOS suspends/drops the WebSocket whenever the app is backgrounded (there's
        // no UIBackgroundModes entry for persistent networking, deliberately — a
        // smart-home control app doesn't need one). Without this, returning to the
        // app after even briefly switching away or locking the screen left it stuck
        // showing stale cached state with a dead socket — any control would silently
        // fail until the user force-quit and relaunched. That's what was actually
        // behind "login times out fairly fast" (not a Remember Me/token-expiry
        // issue — the cached token itself is valid for 30 days per the real app's
        // own protocol).
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillEnterForeground() {
        // Don't interrupt an in-flight login/connect attempt, but DO re-verify a
        // seemingly-".ready" session — iOS can silently drop the WebSocket while the
        // app is suspended without ever running our onDisconnect handler (the process
        // itself isn't executing code during suspension), so `state` can still read
        // .ready from before backgrounding even though the underlying socket is dead.
        guard state != .connecting, state != .loggingIn else { return }
        restoreSession()
    }

    // MARK: - Startup

    /// Tries a cached token first; falls back to stored email/password; otherwise stays loggedOut.
    func restoreSession() {
        accountEmail = KeychainStore.get(.email)

        guard let cachedToken = KeychainStore.get(.token) else {
            loginWithStoredCredentialsIfAvailable()
            return
        }

        connectAndLoad(token: cachedToken) { [weak self] result in
            if case .failure = result {
                self?.loginWithStoredCredentialsIfAvailable()
            }
        }
    }

    private func loginWithStoredCredentialsIfAvailable() {
        guard let email = KeychainStore.get(.email), let password = KeychainStore.get(.password) else { return }
        login(email: email, password: password, remember: true)
    }

    // MARK: - Auth

    func login(email: String, password: String, remember: Bool) {
        state = .loggingIn
        http.login(email: email, password: password) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.state = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            case .success(let (userId, token)):
                if remember {
                    KeychainStore.set(email, for: .email)
                    KeychainStore.set(password, for: .password)
                    KeychainStore.set(token, for: .token)
                    KeychainStore.set(String(userId), for: .userId)
                }
                self.accountEmail = email
                self.connectAndLoad(token: token) { _ in }
            }
        }
    }

    func logout() {
        ws?.disconnect()
        ws = nil
        token = nil
        devices = []
        accountEmail = nil
        KeychainStore.clearAll()
        state = .loggedOut
    }

    private func connectAndLoad(token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Close out any previous socket before starting a new one — relevant now that
        // connectAndLoad can be re-entered from applicationWillEnterForeground while a
        // prior (possibly still-technically-alive) socket exists, not just on first
        // login. Without this, re-entering here could leak the old connection.
        ws?.disconnect()
        ws = nil

        state = .connecting
        self.token = token

        // Safety net: if Starscream never fires any delegate callback at all (no
        // .connected, .error, or .disconnected — observed as a real possibility, not
        // hypothetical), the UI would otherwise be stuck on the "Connecting" spinner
        // forever with no feedback. Guarding on state == .connecting (rather than a
        // separate resolved flag) is sufficient: every real success/failure path below
        // moves state to .ready or .error before this fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.state == .connecting else { return }
            self.state = .error("Connection timed out — the WebSocket never responded.")
            completion(.failure(FanSyncError.requestTimedOut))
        }

        let socket = FanSyncWebSocket()
        // Retain immediately — previously `socket` was only assigned to
        // `self.ws` inside onConnected (i.e. after a successful connection),
        // so nothing kept it alive between `socket.connect()` returning and
        // that callback firing. ARC deallocated it within milliseconds of
        // connect() being called, which (confirmed via device console log:
        // the connection path gets cancelled ~7ms after starting DNS
        // resolution, with no error — a clean teardown, not a network
        // failure) silently tore down the in-flight connection before it
        // could ever complete.
        self.ws = socket
        socket.onDeviceChange = { [weak self] deviceId, changes, connected in
            self?.applyChange(deviceId: deviceId, changes: changes, connected: connected)
        }
        socket.onDisconnect = { [weak self] error in
            guard let self else { return }
            switch self.state {
            case .ready:
                self.state = .error("Connection lost")
            case .connecting:
                // The socket failed/dropped before login+device-load ever completed —
                // without this branch the UI was stuck on the "Connecting" spinner
                // forever with no feedback, since onDisconnect only handled the
                // already-ready case.
                let message = (error as? LocalizedError)?.errorDescription ?? error?.localizedDescription ?? "Connection failed"
                self.state = .error(message)
                completion(.failure(error ?? FanSyncError.notConnected))
            default:
                break
            }
        }
        socket.onConnected = { [weak self, weak socket] in
            guard let self, let socket else { return }
            socket.login(token: token) { loginResult in
                switch loginResult {
                case .failure(let error):
                    self.state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
                    completion(.failure(error))
                case .success:
                    self.ws = socket
                    self.groupStore.attach(ws: socket)
                    self.refreshDevices { refreshResult in
                        switch refreshResult {
                        case .failure(let error):
                            self.state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
                            completion(.failure(error))
                        case .success:
                            // Groups are loaded best-effort after devices — a failure
                            // here shouldn't block the rest of the app from becoming
                            // usable, since device control doesn't depend on groups.
                            self.groupStore.reload { _ in }
                            self.state = .ready
                            completion(.success(()))
                        }
                    }
                }
            }
        }
        socket.connect()
    }

    // MARK: - Devices

    func refreshDevices(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ws else { completion(.failure(FanSyncError.notConnected)); return }

        ws.listDevices { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let list):
                self.loadDetails(for: list, index: 0, accumulated: [], completion: completion)
            }
        }
    }

    private func loadDetails(
        for list: [ListDevicesResponse.Device],
        index: Int,
        accumulated: [FanDevice],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard index < list.count else {
            self.devices = accumulated
            completion(.success(()))
            return
        }
        guard let ws else { completion(.failure(FanSyncError.notConnected)); return }

        let d = list[index]
        ws.getDevice(d.device) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let detail):
                var next = accumulated
                next.append(FanDevice(
                    id: d.device,
                    displayName: d.properties.displayName,
                    status: detail.data.status,
                    isConnected: (detail.data.connected ?? 1) == 1,
                    hidesLightDimmer: d.properties.hideLightDimmer ?? false,
                    hidesFanDirection: d.properties.hideFanDirection ?? false
                ))
                self.loadDetails(for: list, index: index + 1, accumulated: next, completion: completion)
            }
        }
    }

    private func applyChange(deviceId: String, changes: [String: Int]?, connected: Int?) {
        guard let idx = devices.firstIndex(where: { $0.id == deviceId }) else { return }
        var updated = devices
        if let changes { updated[idx].apply(changes: changes) }
        if let connected { updated[idx].isConnected = connected == 1 }
        devices = updated
    }

    // MARK: - Controls

    func setFanPower(_ device: FanDevice, on: Bool) { fireAndForget(device, [.fanPower: on ? 1 : 0]) }
    func setFanPercent(_ device: FanDevice, percent: Int) { fireAndForgetDebounced(device, .fanPercent, percent) }
    func setFanMode(_ device: FanDevice, mode: FanMode) { fireAndForget(device, [.fanMode: mode.rawValue]) }
    func setFanDirection(_ device: FanDevice, direction: FanDirection) { fireAndForget(device, [.fanDirection: direction.rawValue]) }
    func setLightPower(_ device: FanDevice, on: Bool) { fireAndForget(device, [.lightPower: on ? 1 : 0]) }
    func setLightPercent(_ device: FanDevice, percent: Int) { fireAndForgetDebounced(device, .lightPercent, percent) }
    func setHomeAway(_ device: FanDevice, on: Bool) { fireAndForget(device, [.homeAway: on ? 1 : 0]) }

    private func fireAndForget(_ device: FanDevice, _ fields: [FanField: Int]) {
        guard let ws else { return }
        applyOptimisticUpdate(device: device, fields: fields)
        ws.setDevice(device.id, fields: fields)
    }

    /// Debounces slider-driven set requests: the optimistic local UI update happens
    /// immediately (so dragging still feels responsive), but the actual network
    /// request is delayed and coalesced — only the last value within a ~300ms quiet
    /// window after the user stops moving the slider is actually sent. See
    /// `pendingSetWork`'s doc comment for why this is necessary.
    private func fireAndForgetDebounced(_ device: FanDevice, _ field: FanField, _ value: Int) {
        applyOptimisticUpdate(device: device, fields: [field: value])

        let key = "\(device.id):\(field.rawValue)"
        pendingSetWork[key]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSetWork.removeValue(forKey: key)
            self.ws?.setDevice(device.id, fields: [field: value])
        }
        pendingSetWork[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func applyOptimisticUpdate(device: FanDevice, fields: [FanField: Int]) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        var statusDelta: [String: Int] = [:]
        for (f, v) in fields { statusDelta[f.rawValue] = v }
        var updated = devices
        updated[idx].apply(changes: statusDelta)
        devices = updated
    }
}
