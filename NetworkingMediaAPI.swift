import Foundation

// Ответы бэкенда
struct JobStatus: Decodable {
    let ok: Bool
    let job_id: String
    let status: String
    let result: ResultObj?
    let error: String?

    struct ResultObj: Decodable {
        let output_url: String?
        let progress: Int?
        let stage: String?
    }
}

struct EnqueueResp: Decodable {
    let ok: Bool
    let job_id: String
    let status_url: String
}

// Мини-SDK для Media Toolbox
enum MediaAPI {
    static func enqueueVideoFilter(url: String, preset: String, intensity: Double = 0.7) async throws -> EnqueueResp {
        try await API.postJSON("/media/filter/video",
                               body: ["url": url, "preset": preset, "intensity": intensity])
    }

    static func pollJob(jobID: String) async throws -> JobStatus {
        try await API.getJSON("/media/filter/status", params: ["job_id": jobID])
    }

    static func filterImage(url: String, preset: String, intensity: Double = 0.7) async throws -> String {
        struct R: Decodable { let ok: Bool; let output_url: String }
        let r: R = try await API.postJSON("/media/filter/image",
                                          body: ["url": url, "preset": preset, "intensity": intensity])
        return r.output_url
    }

    static func reelCover(videoURL: String, at: Double = 1.0, overlay: [String:Any]? = nil) async throws -> String {
        struct R: Decodable { let ok: Bool; let cover_url: String }
        let r: R = try await API.postJSON("/media/reel-cover",
                                          body: ["video_url": videoURL, "at": at, "overlay": overlay as Any])
        return r.cover_url
    }

    static func watermark(url: String, logoURL: String, position: String = "br", opacity: Double = 0.85, type: String? = nil) async throws -> String {
        struct R: Decodable { let ok: Bool; let output_url: String }
        let body: [String:Any] = ["url": url, "logo_url": logoURL, "position": position, "opacity": opacity, "type": type as Any]
        let r: R = try await API.postJSON("/media/watermark", body: body)
        return r.output_url
    }

    static func resizeImage(url: String, aspect: String = "1:1", maxWidth: Int = 1080, fit: String = "cover", background: String = "black") async throws -> String {
        struct R: Decodable { let ok: Bool; let output_url: String }
        let r: R = try await API.postJSON("/media/resize/image",
                                          body: ["url": url, "target_aspect": aspect, "max_width": maxWidth, "fit": fit, "background": background])
        return r.output_url
    }

    static func compositeCover(frameURL: String, title: String, bg: String = "blur", size: String = "1080x1920") async throws -> String {
        struct R: Decodable { let ok: Bool; let output_url: String }
        let r: R = try await API.postJSON("/media/composite/cover",
                                          body: ["frame_url": frameURL, "title": title, "bg": bg, "size": size])
        return r.output_url
    }

    static func validate(url: String, type: String, target: String = "REELS") async throws -> [String:Any] {
        try await API.postJSONDict("/media/validate", body: ["url": url, "type": type, "target": target])
    }
}
