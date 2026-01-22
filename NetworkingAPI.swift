import Foundation

// MARK: - Base API

enum API {
    static let baseURL = URL(string: "https://ig-planner-backend.onrender.com")!

    static func url(_ path: String) -> URL {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.path = path.hasPrefix("/") ? path : "/" + path
        return comps.url!
    }
}

// MARK: - Logging (универсальное логирование всех сетевых ответов)

extension URLSession {
    static let logged: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
}

func logResponse(_ data: Data, _ resp: URLResponse) {
    guard let http = resp as? HTTPURLResponse else { return }
    #if DEBUG
    print("🌐 [\(http.statusCode)] \(http.url?.absoluteString ?? "")")
    if let body = String(data: data, encoding: .utf8) {
        print("🌐 body:", body)
    }
    #endif
}

// MARK: - Health API

struct HealthResponse: Decodable {
    let ok: Bool
    let ffmpeg: Bool?
    let pillow: Bool?
}

enum HealthAPI {
    static func ping() async throws -> HealthResponse {
        // создаём GET-запрос к /health
        var req = URLRequest(url: API.url("/health"))
        req.httpMethod = "GET"

        // вызываем логируемую сессию
        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)

        // проверяем статус HTTP
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw NSError(
                domain: "HTTP",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]
            )
        }

        // декодируем JSON-ответ {"ok":true,"ffmpeg":true,"pillow":true}
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case badStatus(Int, String)
    case noHTTP

    var errorDescription: String? {
        switch self {
        case .noHTTP:
            return "No HTTP response"
        case .badStatus(let code, let body):
            return "HTTP \(code): \(body.prefix(400))"
        }
    }
}

// MARK: - JSON helpers

extension API {
    static func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)

        guard let http = resp as? HTTPURLResponse else { throw APIError.noHTTP }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func postJSON<T: Decodable, B: Encodable>(_ url: URL, body: B) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)

        guard let http = resp as? HTTPURLResponse else { throw APIError.noHTTP }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Path + Query overloads

extension API {
    static func url(_ path: String, _ query: [URLQueryItem]) -> URL {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.path = path
        if !query.isEmpty { comps.queryItems = query }
        return comps.url!
    }

    static func getJSON<T: Decodable>(
        _ path: String,
        params: [String: Any]? = nil
    ) async throws -> T {
        let items = (params ?? [:]).map {
            URLQueryItem(name: $0.key, value: String(describing: $0.value))
        }
        let url = API.url(path.hasPrefix("/") ? path : "/" + path, items)
        return try await getJSON(url)
    }

    static func postJSON<T: Decodable>(
        _ path: String,
        body: [String: Any]
    ) async throws -> T {
        let url = API.url(path.hasPrefix("/") ? path : "/" + path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)

        guard let http = resp as? HTTPURLResponse else { throw APIError.noHTTP }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Raw JSON Dict helper

extension API {
    static func postJSONDict(
        _ path: String,
        body: [String: Any]
    ) async throws -> [String: Any] {
        let url = API.url(path.hasPrefix("/") ? path : "/" + path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)

        guard let http = resp as? HTTPURLResponse else { throw APIError.noHTTP }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, body)
        }
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return (obj as? [String: Any]) ?? [:]
    }
}
