import Foundation
import UIKit

// Обёртка: принимаем локальный fileURL, читаем изображение и
// переиспользуем уже существующий upload(image:jpegQuality:)
extension CloudinaryUploader {
    static func uploadImage(fileURL: URL, jpegQuality: CGFloat = 0.92) async throws -> String {
        // читаем данные и декодируем UIImage
        let data = try Data(contentsOf: fileURL)
        guard let img = UIImage(data: data) else {
            throw NSError(
                domain: "Cloudinary",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Image decode failed"]
            )
        }
        // используем уже реализованный метод
        return try await upload(image: img, jpegQuality: jpegQuality)
    }
}
enum CloudinaryConfig {
    static let cloud = "YOUR_CLOUD_NAME"              // см. ENV CLOUDINARY_CLOUD
    static let unsignedPreset = "YOUR_UNSIGNED_PRESET"// см. ENV CLOUDINARY_UNSIGNED_PRESET
}

enum CloudinaryUploader {
    static func upload(image: UIImage, jpegQuality: CGFloat = 0.92) async throws -> String {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            throw NSError(domain: "Cloudinary", code: -1, userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
        }
        let url = URL(string: "https://api.cloudinary.com/v1_1/\(CloudinaryConfig.cloud)/image/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        // multipart/form-data
        let boundary = "----\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("upload_preset", CloudinaryConfig.unsignedPreset)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let s = String(data: respData, encoding: .utf8) ?? "<binary>"
            throw NSError(domain: "Cloudinary", code: -2, userInfo: [NSLocalizedDescriptionKey: s])
        }
        struct R: Decodable { let secure_url: String }
        let r = try JSONDecoder().decode(R.self, from: respData)
        return r.secure_url
    }
}
extension CloudinaryUploader {
    static func uploadVideo(fileURL: URL,
                            preset: String? = nil,
                            mime: String = "video/mp4") async throws -> String {
        let presetToUse = preset ?? CloudinaryConfig.unsignedPreset
        let url = URL(string: "https://api.cloudinary.com/v1_1/\(CloudinaryConfig.cloud)/video/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let boundary = "----\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("upload_preset", presetToUse)

        let data = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let s = String(data: respData, encoding: .utf8) ?? "<binary>"
            throw NSError(domain: "Cloudinary", code: -2, userInfo: [NSLocalizedDescriptionKey: s])
        }
        struct R: Decodable { let secure_url: String }
        return try JSONDecoder().decode(R.self, from: respData).secure_url
    }
}
