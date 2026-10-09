import Foundation

enum FanSyncError: LocalizedError {
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
/// Mirrors HttpApi.post_session / get_session in the reference implementation.
final class FanSyncHTTPClient {
    static let baseURL = URL(string: "https://fanimation.apps.exosite.io")!

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// POST /api:1/session — exchanges email/password for a long-lived bearer JWT.
    func login(email: String, password: String) async throws -> (userId: Int, token: String) {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api:1/session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SessionLoginRequest(email: email, password: password))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FanSyncError.authFailed("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FanSyncError.authFailed("HTTP \(http.statusCode): \(body)")
        }

        do {
            let decoded = try JSONDecoder().decode(SessionLoginResponse.self, from: data)
            return (decoded.id, decoded.token)
        } catch {
            throw FanSyncError.decodeFailed(error.localizedDescription)
        }
    }

    /// GET /api:1/session — validates a cached token is still accepted server-side.
    func validateToken(_ token: String) async -> Bool {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api:1/session"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(SessionStatusResponse.self, from: data)
        else { return false }

        return decoded.status == "valid"
    }
}
