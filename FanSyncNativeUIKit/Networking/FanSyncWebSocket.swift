import Foundation
import Starscream

/// Bidirectional control channel to the FanSync cloud, using Starscream (iOS 12 compatible;
/// URLSessionWebSocketTask requires iOS 13). Mirrors the reference Python client's
/// `Websocket` class (login, lst_device, get, set) plus unsolicited `device_change` push events.
final class FanSyncWebSocket: WebSocketDelegate {
    static let apiURL = URL(string: "wss://fanimation.apps.exosite.io/api:1/phone")!

    private var socket: WebSocket?
    private var nextId = 1
    private var pending: [Int: (Result<Data, Error>) -> Void] = [:]
    private var pendingTimeouts: [Int: DispatchWorkItem] = [:]

    /// Fired once the socket is open and ready for `login(token:)`.
    var onConnected: (() -> Void)?
    /// Fired for unsolicited device_change events pushed by the server.
    var onDeviceChange: ((String, [String: Int]) -> Void)?
    /// Fired when the socket drops unexpectedly (not via an explicit disconnect()).
    var onDisconnect: ((Error?) -> Void)?

    private(set) var isConnected = false

    private func allocateId() -> Int {
        defer { nextId += 1 }
        return nextId
    }

    func connect() {
        var request = URLRequest(url: Self.apiURL)
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.delegate = self
        self.socket = socket
        socket.connect()
    }

    func login(token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = allocateId()
        let req = LoginWSRequest(id: id, data: .init(token: token))
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    let resp = try JSONDecoder().decode(WSLoginResponse.self, from: data)
                    if resp.status == "ok" {
                        completion(.success(()))
                    } else {
                        completion(.failure(FanSyncError.authFailed("Websocket login status: \(resp.status)")))
                    }
                } catch {
                    completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
                }
            }
        }
    }

    func listDevices(completion: @escaping (Result<[ListDevicesResponse.Device], Error>) -> Void) {
        let id = allocateId()
        let req = ListDevicesWSRequest(id: id)
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let data):
                do {
                    let resp = try JSONDecoder().decode(ListDevicesResponse.self, from: data)
                    completion(.success(resp.data))
                } catch {
                    completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
                }
            }
        }
    }

    func getDevice(_ deviceId: String, completion: @escaping (Result<GetDeviceResponse, Error>) -> Void) {
        let id = allocateId()
        let req = GetDeviceWSRequest(id: id, device: deviceId)
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let data):
                do {
                    completion(.success(try JSONDecoder().decode(GetDeviceResponse.self, from: data)))
                } catch {
                    completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
                }
            }
        }
    }

    /// Fire-and-forget set — the server does not ack `set` with meaningful data in the
    /// reference implementation; state changes arrive via the device_change push instead.
    func setDevice(_ deviceId: String, fields: [FanField: Int]) {
        let id = allocateId()
        var data: [String: String] = [:]
        for (field, value) in fields { data[field.rawValue] = String(value) }
        let req = SetDeviceWSRequest(id: id, device: deviceId, data: data)
        send(req)
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
        failAllPending(FanSyncError.notConnected)
    }

    // MARK: - Plumbing

    private func send<T: WSRequest>(_ request: T) {
        guard let socket else { return }
        guard let payload = try? JSONEncoder().encode(request),
              let text = String(data: payload, encoding: .utf8)
        else { return }
        socket.write(string: text)
    }

    /// Sends a request and awaits the response envelope matching its `id`, with a timeout.
    private func sendAndAwait<T: WSRequest>(_ request: T, id: Int, timeout: TimeInterval = 10, completion: @escaping (Result<Data, Error>) -> Void) {
        guard socket != nil else {
            completion(.failure(FanSyncError.notConnected))
            return
        }

        pending[id] = completion

        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self, let callback = self.pending.removeValue(forKey: id) else { return }
            self.pendingTimeouts.removeValue(forKey: id)
            callback(.failure(FanSyncError.requestTimedOut))
        }
        pendingTimeouts[id] = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        send(request)
    }

    private func resolvePending(id: Int, result: Result<Data, Error>) {
        pendingTimeouts.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?(result)
    }

    private func failAllPending(_ error: Error) {
        for (id, _) in pending { resolvePending(id: id, result: .failure(error)) }
    }

    // MARK: - WebSocketDelegate

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            isConnected = true
            DispatchQueue.main.async { [weak self] in self?.onConnected?() }

        case .disconnected(let reason, let code):
            isConnected = false
            let error = FanSyncError.serverError("Disconnected: \(reason) (\(code))")
            failAllPending(error)
            DispatchQueue.main.async { [weak self] in self?.onDisconnect?(error) }

        case .text(let text):
            handle(text)

        case .binary(let data):
            if let text = String(data: data, encoding: .utf8) { handle(text) }

        case .error(let error):
            isConnected = false
            failAllPending(error ?? FanSyncError.notConnected)
            DispatchQueue.main.async { [weak self] in self?.onDisconnect?(error) }

        case .cancelled:
            isConnected = false
            failAllPending(FanSyncError.notConnected)

        case .ping, .pong, .viabilityChanged, .reconnectSuggested, .peerClosed:
            break
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let envelope = try? JSONDecoder().decode(WSEnvelope.self, from: data) else { return }

        if let event = envelope.event, event == "device_change" {
            if let change = try? JSONDecoder().decode(DeviceChangeEvent.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceChange?(change.data.device, change.data.changes.status)
                }
            }
            return
        }

        if let id = envelope.id {
            resolvePending(id: id, result: .success(data))
        }
    }
}
