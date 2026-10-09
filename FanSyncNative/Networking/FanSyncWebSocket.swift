import Foundation

/// Bidirectional control channel to the FanSync cloud, mirroring the reference
/// Python client's `Websocket` class (login, lst_device, get, set) plus unsolicited
/// `device_change` push events.
@MainActor
final class FanSyncWebSocket: NSObject {
    static let apiURL = URL(string: "wss://fanimation.apps.exosite.io/api:1/phone")!

    private var task: URLSessionWebSocketTask?
    private var session: URLSession!
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]

    /// Fired for unsolicited device_change events pushed by the server.
    var onDeviceChange: ((String, [String: Int]) -> Void)?
    /// Fired when the socket drops unexpectedly (not via an explicit close()).
    var onDisconnect: ((Error?) -> Void)?

    private(set) var isConnected = false

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    }

    private func allocateId() -> Int {
        defer { nextId += 1 }
        return nextId
    }

    func connect() async throws {
        let task = session.webSocketTask(with: Self.apiURL)
        self.task = task
        task.resume()
        isConnected = true
        receiveLoop()
    }

    func login(token: String) async throws {
        let id = allocateId()
        let req = LoginWSRequest(id: id, data: .init(token: token))
        let data = try await sendAndAwait(req, id: id)
        let resp = try JSONDecoder().decode(WSLoginResponse.self, from: data)
        guard resp.status == "ok" else {
            throw FanSyncError.authFailed("Websocket login status: \(resp.status)")
        }
    }

    func listDevices() async throws -> [ListDevicesResponse.Device] {
        let id = allocateId()
        let req = ListDevicesWSRequest(id: id)
        let data = try await sendAndAwait(req, id: id)
        let resp = try JSONDecoder().decode(ListDevicesResponse.self, from: data)
        return resp.data
    }

    func getDevice(_ deviceId: String) async throws -> GetDeviceResponse {
        let id = allocateId()
        let req = GetDeviceWSRequest(id: id, device: deviceId)
        let data = try await sendAndAwait(req, id: id)
        return try JSONDecoder().decode(GetDeviceResponse.self, from: data)
    }

    /// Fire-and-forget set — the server does not ack `set` with meaningful data in the
    /// reference implementation; state changes arrive via the device_change push instead.
    func setDevice(_ deviceId: String, fields: [FanField: Int]) async throws {
        let id = allocateId()
        var data: [String: String] = [:]
        for (field, value) in fields { data[field.rawValue] = String(value) }
        let req = SetDeviceWSRequest(id: id, device: deviceId, data: data)
        try await send(req)
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: "goodbye".data(using: .utf8))
        task = nil
        isConnected = false
        failAllPending(FanSyncError.notConnected)
    }

    // MARK: - Plumbing

    private func send<T: WSRequest>(_ request: T) async throws {
        guard let task else { throw FanSyncError.notConnected }
        let payload = try JSONEncoder().encode(request)
        guard let text = String(data: payload, encoding: .utf8) else {
            throw FanSyncError.decodeFailed("Could not encode request as UTF-8")
        }
        try await task.send(.string(text))
    }

    /// Sends a request and awaits the response envelope matching its `id`, with a timeout.
    private func sendAndAwait<T: WSRequest>(_ request: T, id: Int, timeout: TimeInterval = 10) async throws -> Data {
        try await send(request)

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    Task { @MainActor in
                        self.pending[id] = cont
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw FanSyncError.requestTimedOut
            }
            guard let result = try await group.next() else {
                throw FanSyncError.requestTimedOut
            }
            group.cancelAll()
            return result
        }
    }

    private func failAllPending(_ error: Error) {
        for (_, cont) in pending { cont.resume(throwing: error) }
        pending.removeAll()
    }

    private func receiveLoop() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .failure(let error):
                    self.isConnected = false
                    self.failAllPending(error)
                    self.onDisconnect?(error)
                case .success(let message):
                    self.handle(message)
                    self.receiveLoop()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let envelope = try? JSONDecoder().decode(WSEnvelope.self, from: data) else { return }

        if let event = envelope.event, event == "device_change" {
            if let change = try? JSONDecoder().decode(DeviceChangeEvent.self, from: data) {
                onDeviceChange?(change.data.device, change.data.changes.status)
            }
            return
        }

        if let id = envelope.id, let cont = pending.removeValue(forKey: id) {
            cont.resume(returning: data)
        }
    }
}
