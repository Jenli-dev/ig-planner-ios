import SwiftUI
import UIKit   // нужно для UIImage

@MainActor
final class QuickShotVM: ObservableObject {
    @Published var original: UIImage? {
        didSet {
            // если выбрали новое фото — сбрасываем предыдущие результаты
            uploadedURL = nil
            resultURL = nil
            errorText = nil
        }
    }
    @Published var uploadedURL: String?
    @Published var resultURL: String?

    @Published var preset: String = "cinematic"
    @Published var intensity: Double = 0.7 { // страховка границ
        didSet { intensity = min(1.0, max(0.0, intensity)) }
    }

    @Published var isUploading = false
    @Published var isProcessing = false
    @Published var errorText: String?

    // Загрузка исходника в Cloudinary (если ещё не загружен)
    func uploadIfNeeded() async {
        guard uploadedURL == nil, let img = original else { return }
        isUploading = true
        errorText = nil
        defer { isUploading = false }
        do {
            let url = try await CloudinaryUploader.upload(image: img)
            uploadedURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    // Применение фильтра к загруженному фото
    func applyFilter() async {
        guard let src = uploadedURL else {
            errorText = "No source photo."
            return
        }

        isProcessing = true
        errorText = nil
        resultURL = nil
        defer { isProcessing = false }

        do {
            let out = try await MediaAPI.filterImage(
                url: src,
                preset: preset,           // <— было selectedPreset
                intensity: intensity
            )
            resultURL = out
        } catch {
            errorText = error.localizedDescription
        }
    }
}
