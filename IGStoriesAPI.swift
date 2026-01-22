import Foundation

// MARK: - Response Models

struct IGStoryPublishResponse: Decodable {
    let ok: Bool
    let creation_id: String?
    let published: IGStoryPublished?
    let stage: String?              // create | processing | publishing | done | error
    let error: IGStoryError?
    let status: Int?                 // HTTP status code if error
}

struct IGStoryPublished: Decodable {
    let id: String?
    let permalink: String?
}

struct IGStoryError: Decodable {
    // Error can be a dict or string, so we decode as flexible
    let detail: String?
    let message: String?
    let raw: String?
    
    private enum CodingKeys: String, CodingKey {
        case detail, message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detail = try? container.decode(String.self, forKey: .detail)
        message = try? container.decode(String.self, forKey: .message)
        
        // Try to decode as raw string if dict decoding fails
        if detail == nil && message == nil {
            let singleContainer = try decoder.singleValueContainer()
            if let str = try? singleContainer.decode(String.self) {
                raw = str
            } else {
                // If it's not a string, we can't decode it as [String: Any] with Codable
                // So we'll just set raw to nil
                raw = nil
            }
        } else {
            raw = nil
        }
    }
}

// MARK: - API Client

enum IGStoriesAPI {
    
    // MARK: - Publish Story Image
    
    /// Publishes an image story to Instagram
    /// - Parameter imageURL: Public URL of the image to publish
    /// - Returns: Response with creation_id and published story info
    static func publishStoryImage(imageURL: String) async throws -> IGStoryPublishResponse {
        let url = API.url("/ig/publish/story/image")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["image_url": imageURL]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)
        
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.noHTTP
        }
        
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, bodyText)
        }
        
        return try JSONDecoder().decode(IGStoryPublishResponse.self, from: data)
    }
    
    // MARK: - Publish Story Video
    
    /// Publishes a video story to Instagram
    /// - Parameter videoURL: Public URL of the video to publish
    /// - Returns: Response with creation_id and published story info
    static func publishStoryVideo(videoURL: String) async throws -> IGStoryPublishResponse {
        let url = API.url("/ig/publish/story/video")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["video_url": videoURL]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, resp) = try await URLSession.logged.data(for: req)
        logResponse(data, resp)
        
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.noHTTP
        }
        
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.badStatus(http.statusCode, bodyText)
        }
        
        return try JSONDecoder().decode(IGStoryPublishResponse.self, from: data)
    }
}
