import Foundation

// MARK: - Response Models

struct AIGenerateResponse: Decodable {
    let ok: Bool
    let job_id: String
    let status_url: String
}

struct AIJobStatus: Decodable {
    let ok: Bool
    let job_id: String
    let kind: String?
    let status: String          // PENDING | RUNNING | DONE | ERROR
    let stage: String?          // queued | running | uploading | done | error
    let result: AIJobResult?
    let error: String?
}

struct AIJobResult: Codable {
    // For T2I/I2I
    let images: [String]?       // Array of image URLs
    let provider: String?       // "fal" | "replicate"
    let meta: AIMeta?
    
    // For Batch
    let items: [AIBatchItem]?
    let summary: AIBatchSummary?
    
    // Fallback: raw dict decoding
    private enum CodingKeys: String, CodingKey {
        case images, provider, meta, items, summary
    }
}

struct AIMeta: Codable {
    let model: String?
    let aspect_ratio: String?
    let seed: Int?
}

struct AIBatchItem: Codable {
    let source_image_url: String
    let generated_images: [String]
    let meta: AIMeta?
    let error: String?
}

struct AIBatchSummary: Codable {
    let count_sources: Int
    let variants_per_image: Int
    let total_generated: Int
}

// MARK: - API Client

enum AIGenerationAPI {
    
    // MARK: - Text-to-Image
    
    static func generateTextToImage(
        prompt: String,
        aspectRatio: String = "1:1",
        steps: Int? = nil,
        seed: Int? = nil
    ) async throws -> AIGenerateResponse {
        var body: [String: Any] = [
            "prompt": prompt,
            "aspect_ratio": aspectRatio
        ]
        if let steps = steps {
            body["steps"] = steps
        }
        if let seed = seed {
            body["seed"] = seed
        }
        return try await API.postJSON("/ai/generate/text", body: body)
    }
    
    // MARK: - Image-to-Image
    
    static func generateImageToImage(
        imageURL: String,
        prompt: String,
        strength: Double? = nil,
        aspectRatio: String = "3:4",
        steps: Int? = nil,
        seed: Int? = nil
    ) async throws -> AIGenerateResponse {
        var body: [String: Any] = [
            "image_url": imageURL,
            "prompt": prompt,
            "aspect_ratio": aspectRatio
        ]
        if let strength = strength {
            body["strength"] = strength
        }
        if let steps = steps {
            body["steps"] = steps
        }
        if let seed = seed {
            body["seed"] = seed
        }
        return try await API.postJSON("/ai/generate/image", body: body)
    }
    
    // MARK: - Avatar Batch
    
    static func generateAvatarBatch(
        imageURLs: [String],
        prompt: String,
        strength: Double? = nil,
        aspectRatio: String = "1:1",
        steps: Int? = nil,
        variantsPerImage: Int = 1,
        seed: Int? = nil
    ) async throws -> AIGenerateResponse {
        guard imageURLs.count >= 15 && imageURLs.count <= 50 else {
            throw NSError(
                domain: "AIGenerationAPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "image_urls must contain 15-50 URLs"]
            )
        }
        guard variantsPerImage >= 1 && variantsPerImage <= 4 else {
            throw NSError(
                domain: "AIGenerationAPI",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "variants_per_image must be 1-4"]
            )
        }
        
        var body: [String: Any] = [
            "image_urls": imageURLs,
            "prompt": prompt,
            "aspect_ratio": aspectRatio,
            "variants_per_image": variantsPerImage
        ]
        if let strength = strength {
            body["strength"] = strength
        }
        if let steps = steps {
            body["steps"] = steps
        }
        if let seed = seed {
            body["seed"] = seed
        }
        return try await API.postJSON("/ai/generate/batch", body: body)
    }
    
    // MARK: - Job Status
    
    static func getJobStatus(jobID: String) async throws -> AIJobStatus {
        return try await API.getJSON("/ai/status", params: ["job_id": jobID])
    }
    
    // MARK: - Polling Helper
    
    /// Polls job status until completion (DONE or ERROR) or timeout
    /// - Parameters:
    ///   - jobID: Job ID to poll
    ///   - interval: Polling interval in seconds (default 2)
    ///   - maxWait: Maximum wait time in seconds (default 300 = 5 minutes)
    /// - Returns: Final job status
    static func pollJobStatus(
        jobID: String,
        interval: TimeInterval = 2.0,
        maxWait: TimeInterval = 300.0
    ) async throws -> AIJobStatus {
        let startTime = Date()
        var lastStatus: AIJobStatus?
        
        while Date().timeIntervalSince(startTime) < maxWait {
            let status = try await getJobStatus(jobID: jobID)
            lastStatus = status
            
            if status.status == "DONE" || status.status == "ERROR" {
                return status
            }
            
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        // Timeout - return last known status or throw
        if let last = lastStatus {
            return last
        }
        throw NSError(
            domain: "AIGenerationAPI",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "Polling timeout after \(maxWait) seconds"]
        )
    }
}
