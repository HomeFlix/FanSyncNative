import Foundation
import SwiftUI

@MainActor
final class FanSyncStore: ObservableObject {
    enum SessionState: Equatable {
        case loggedOut
        case loggingIn
        case connecting
        case ready
        case error(String)
    }

    @Published private(set) var state: SessionState = .loggedOut
    @Published private(set) var devices: [FanDevice] = []
    @Published private(set) var accountEmail: String?

    private let http = FanSyncHTTPClient()
    private var ws: FanSyncWebSocket?
    private var token: String?

    // MARK: - Startup

    /// Tries a cached token first; falls back to stored email/password; otherwise stays loggedOut.
    func restoreSession() async {
        accountEmail = KeychainStore.get(.email)

        if let cachedToken = KeychainStore.get(.token) {
            do {
                try await connectAndLoad(token: cachedToken)
                return
            } catch {
                // Cached token rejected; fall through to password re-auth if we have one.
            }
        }

        if let email = KeychainStore.get(.email), let password = KeychainStore.get(.password) {
            await login(email: email, password: password, remember: true)
        }
    }

    // MARK: - Auth

    func login(email: String, password: String, remember: Bool) async {
        state = .loggingIn
        do {
            let (userId, token) = try await http.login(email: email, password: password)
            if remember {
                KeychainStore.set(email, for: .email)
                KeychainStore.set(password, for: .password)
                KeychainStore.set(token, for: .token)
                KeychainStore.set(String(userId), for: .userId)
            }
            accountEmail = email
            try await connectAndLoad(token: token)
        } catch {
            state = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func logout() {
        ws?.close()
        ws = nil
        token = nil
        devices = []
        accountEmail = nil
        KeychainStore.clearAll()
        state = .loggedOut
    }

    private func connectAndLoad(token: String) async throws {
        state = .connecting
        self.token = token

        let socket = FanSyncWebSocket()
        socket.onDeviceChange = { [weak self] deviceId, changes in
            Task { @MainActor in self?.applyChange(deviceId: deviceId, changes: changes) }
        }
        socket.onDisconnect = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.state == .ready { self.state = .error("Connection lost") }
            }
        }

        try await socket.connect()
        try await socket.login(token: token)
        self.ws = socket

        try await refreshDevices()
        state = .ready
    }

    // MARK: - Devices

    func refreshDevices() async throws {
        guard let ws else { throw FanSyncError.notConnected }
        let list = try await ws.listDevices()

        var loaded: [FanDevice] = []
        for d in list {
            let detail = try await ws.getDevice(d.device)
            loaded.append(FanDevice(id: d.device, displayName: d.properties.displayName, status: detail.data.status))
        }
        devices = loaded
    }

    private func applyChange(deviceId: String, changes: [String: Int]) {
        guard let idx = devices.firstIndex(where: { $0.id == deviceId }) else { return }
        devices[idx].apply(changes: changes)
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
            devices[idx].apply(changes: statusDelta)
        }
        Task {
            do { try await ws.setDevice(device.id, fields: fields) }
            catch { state = .error((error as? LocalizedError)?.errorDescription ?? "\(error)") }
        }
    }
}
