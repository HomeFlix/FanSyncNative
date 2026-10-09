import Foundation

enum FanSyncError: Error, LocalizedError {
    case authFailed(String)
    case notConnected
    case requestTimedOut
    case decodeFailed(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return "Login failed: \(msg)"
        case .notConnected: return "Not connected to FanSync"
        case .requestTimedOut: return "Request timed out"
        case .decodeFailed(let msg): return "Failed to parse response: \(msg)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

/// REST login against Fanimation's Exosite-backed cloud API.
/// Completion-handler based (no async/await — that language feature's floor is iOS 13
/// even with backward deployment, and this app targets iOS 12).
final class FanSyncHTTPClient {
    static let baseURL = URL(string: "https://fanimation.apps.exosite.io")!

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// POST /api:1/session — exchanges email/password for a long-lived bearer JWT.
    func login(email: String, password: String, completion: @escaping (Result<(userId: Int, token: String), Error>) -> Void) {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api:1/session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(SessionLoginRequest(email: email, password: password))
        } catch {
            completion(.failure(FanSyncError.decodeFailed(error.localizedDescription)))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(FanSyncError.authFailed("No HTTP response"))) }
                return
            }
            guard http.statusCode == 200, let data else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async { completion(.failure(FanSyncError.authFailed("HTTP \(http.statusCode): \(body)"))) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(SessionLoginResponse.self, from: data)
                DispatchQueue.main.async { completion(.success((decoded.id, decoded.token))) }
            } catch {
                DispatchQueue.main.async { completion(.failure(FanSyncError.decodeFailed(error.localizedDescription))) }
            }
        }.resume()
    }

    /// GET /api:1/session — validates a cached token is still accepted server-side.
    func validateToken(_ token: String, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api:1/session"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { data, response, _ in
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let decoded = try? JSONDecoder().decode(SessionStatusResponse.self, from: data)
            else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async { completion(decoded.status == "valid") }
        }.resume()
    }
}
