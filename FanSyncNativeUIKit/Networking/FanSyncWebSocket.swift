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
    /// TEMPORARY diagnostic: last few raw frames received, surfaced in timeout errors
    /// so a hung request's cause is visible in the UI without needing device console
    /// access. Remove once WebSocket response decoding is confirmed solid.
    private var recentRawFrames: [String] = []

    /// Fired once the socket is open and ready for `login(token:)`.
    var onConnected: (() -> Void)?
    /// Fired for unsolicited device_change events pushed by the server. `connected` is
    /// non-nil only when the push specifically reported a connectivity change (its own
    /// separate event shape, not bundled with status field changes — see
    /// DeviceChangeEvent.Changes).
    var onDeviceChange: ((String, [String: Int]?, Int?) -> Void)?
    /// Fired for unsolicited set_group events pushed by the server (e.g. from another
    /// connected session changing group membership/name).
    var onGroupChange: ((GetGroupResponse.GroupData) -> Void)?
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
        // Use Starscream's default TCPTransport (Network.framework/NWConnection
        // based) rather than FoundationTransport. Root-caused via a physical
        // device console log capture (iOS 12.5.8): FoundationTransport's raw
        // CFStream socket genuinely connects and completes TLS every time, but
        // its StreamDelegate.stream(_:handle:) only broadcasts .connected when
        // the .openCompleted callback fires for the INPUT stream specifically
        // (FoundationTransport.swift:191-209) — and on this device that
        // callback is never delivered for the input stream, so Starscream never
        // advances past "socket open" to actually write the HTTP Upgrade
        // request (confirmed: zero write/read activity on the socket for the
        // rest of a 15s window, vs. full round-trip activity on the parallel
        // REST/URLSession connection in the same log). This is the same
        // Swift-StreamDelegate/CFStream real-device unreliability we
        // independently found and fixed in our own (now-removed)
        // RawStreamDiagnostic. TCPTransport avoids CFStream/StreamDelegate
        // entirely, so it isn't subject to this failure mode.
        let engine = WSEngine(transport: TCPTransport(), certPinner: FoundationSecurity())
        let socket = WebSocket(request: request, engine: engine)
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
        var data: [String: Int] = [:]
        for (field, value) in fields { data[field.rawValue] = value }
        let req = SetDeviceWSRequest(id: id, device: deviceId, data: data)
        send(req)
    }

    func listGroups(completion: @escaping (Result<[String], Error>) -> Void) {
        let id = allocateId()
        let req = ListGroupsWSRequest(id: id)
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let data):
                do {
                    let resp = try JSONDecoder().decode(ListGroupsResponse.self, from: data)
                    completion(.success(resp.data))
                } catch {
                    completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
                }
            }
        }
    }

    func getGroup(name: String, completion: @escaping (Result<GetGroupResponse.GroupData, Error>) -> Void) {
        let id = allocateId()
        let req = GetGroupWSRequest(id: id, data: .init(name: name))
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let data):
                do {
                    let resp = try JSONDecoder().decode(GetGroupResponse.self, from: data)
                    completion(.success(resp.data))
                } catch {
                    completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
                }
            }
        }
    }

    /// Sends the FULL resulting device list for the group (see SetGroupWSRequest) —
    /// callers must read the current membership first and pass the complete updated
    /// array, matching the real app's exact update pattern.
    func setGroup(name: String, devices: [String], displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = allocateId()
        let req = SetGroupWSRequest(id: id, data: .init(name: name, devices: devices, properties: .init(displayName: displayName)))
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success: completion(.success(()))
            }
        }
    }

    func deleteGroup(name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = allocateId()
        let req = DeleteGroupWSRequest(id: id, data: .init(name: name))
        sendAndAwait(req, id: id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success: completion(.success(()))
            }
        }
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
            let framesDump = self.recentRawFrames.joined(separator: "\n---\n")
            callback(.failure(FanSyncError.requestTimedOut2(framesDump)))
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
        recentRawFrames.append(text)
        if recentRawFrames.count > 5 { recentRawFrames.removeFirst() }

        guard let data = text.data(using: .utf8) else { return }
        guard let envelope = try? JSONDecoder().decode(WSEnvelope.self, from: data) else { return }

        if let event = envelope.event, event == "device_change" {
            if let change = try? JSONDecoder().decode(DeviceChangeEvent.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceChange?(change.data.device, change.data.changes.status, change.data.changes.connected)
                }
            }
            return
        }

        if let event = envelope.event, event == "set_group" {
            if let change = try? JSONDecoder().decode(GroupChangeEvent.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onGroupChange?(change.data)
                }
            }
            return
        }

        if let id = envelope.id {
            resolvePending(id: id, result: .success(data))
        }
    }
}
