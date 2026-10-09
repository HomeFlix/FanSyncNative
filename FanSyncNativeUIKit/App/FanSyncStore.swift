import Foundation

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
        state = .connecting
        self.token = token

        let socket = FanSyncWebSocket()
        socket.onDeviceChange = { [weak self] deviceId, changes in
            self?.applyChange(deviceId: deviceId, changes: changes)
        }
        socket.onDisconnect = { [weak self] _ in
            guard let self else { return }
            if self.state == .ready { self.state = .error("Connection lost") }
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
                    self.refreshDevices { refreshResult in
                        switch refreshResult {
                        case .failure(let error):
                            self.state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)")
                            completion(.failure(error))
                        case .success:
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
                next.append(FanDevice(id: d.device, displayName: d.properties.displayName, status: detail.data.status))
                self.loadDetails(for: list, index: index + 1, accumulated: next, completion: completion)
            }
        }
    }

    private func applyChange(deviceId: String, changes: [String: Int]) {
        guard let idx = devices.firstIndex(where: { $0.id == deviceId }) else { return }
        var updated = devices
        updated[idx].apply(changes: changes)
        devices = updated
    }

    // MARK: - Controls

    func setFanPower(_ device: FanDevice, on: Bool) { fireAndForget(device, [.fanPower: on ? 1 : 0]) }
    func setFanPercent(_ device: FanDevice, percent: Int) { fireAndForget(device, [.fanPercent: percent]) }
    func setFanMode(_ device: FanDevice, mode: FanMode) { fireAndForget(device, [.fanMode: mode.rawValue]) }
    func setFanDirection(_ device: FanDevice, direction: FanDirection) { fireAndForget(device, [.fanDirection: direction.rawValue]) }
    func setLightPower(_ device: FanDevice, on: Bool) { fireAndForget(device, [.lightPower: on ? 1 : 0]) }
    func setLightPercent(_ device: FanDevice, percent: Int) { fireAndForget(device, [.lightPercent: percent]) }
    func setHomeAway(_ device: FanDevice, on: Bool) { fireAndForget(device, [.homeAway: on ? 1 : 0]) }

    private func fireAndForget(_ device: FanDevice, _ fields: [FanField: Int]) {
        guard let ws else { return }
        // Optimistic local update; server device_change push will confirm/correct.
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            var statusDelta: [String: Int] = [:]
            for (f, v) in fields { statusDelta[f.rawValue] = v }
            var updated = devices
            updated[idx].apply(changes: statusDelta)
            devices = updated
        }
        ws.setDevice(device.id, fields: fields)
    }
}
