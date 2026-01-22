import SwiftUI
import UIKit
import Photos

// MARK: - ViewModel
@MainActor
final class WatermarkVM: ObservableObject {
    @Published var mediaURL: String = ""
    @Published var logoURL: String = ""

    /// Позиции: tl / t / tr / l / c / r / bl / b / br
    /// Для MVP используем tl,tr,bl,br,c
    @Published var position: String = "br"
    @Published var opacity: Double = 0.85

    // UI
    @Published var isLoading = false
    @Published var resultURL: String?
    @Published var errorText: String?
    @Published var sourceNote: String?
    @Published var logoNote: String?

    /// Грубое определение типа медиа
    func inferMediaType() -> String? {
        let s = mediaURL.lowercased()
        if s.hasSuffix(".mp4") || s.contains("/video/") { return "video" }
        if s.hasSuffix(".mov") || s.hasSuffix(".m4v") { return "video" }
        if s.hasSuffix(".jpg") || s.hasSuffix(".jpeg") || s.hasSuffix(".png") || s.contains("/image/") { return "image" }
        return nil
    }

    func generate() async {
        isLoading = true
        errorText = nil
        resultURL = nil
        defer { isLoading = false }

        guard !mediaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !logoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            errorText = "Media URL and Logo URL required."
            return
        }

        do {
            let kind = inferMediaType()
            let url = try await MediaAPI.watermark(
                url: mediaURL,
                logoURL: logoURL,
                position: position,
                opacity: opacity,
                type: kind // "video" | "image" | nil
            )
            resultURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Screen
struct WatermarkScreen: View {
    @StateObject private var vm = WatermarkVM()

    // Pickers
    @State private var showPhotoLibrary = false
    @State private var showPhotoCamera  = false
    @State private var showVideoLibrary = false
    @State private var showVideoCamera  = false

    // Logo pickers
    @State private var showLogoLibrary = false
    @State private var showLogoCamera  = false

    // Planner composer
    @State private var showComposer = false
    @State private var plannerImageURL: String?
    @State private var plannerVideoURL: String?
    @State private var plannerCoverURL: String?

    // Alerts
    @State private var saveMessage: String?
    @State private var showSaveAlert = false

    // MARK: Preview subview
    private struct WatermarkLivePreview: View {
        let mediaURL: String
        let logoURL: String
        let position: String // tl / tr / bl / br / c
        let opacity: Double

        private var align: Alignment {
            switch position {
            case "tl": return .topLeading
            case "tr": return .topTrailing
            case "bl": return .bottomLeading
            case "br": return .bottomTrailing
            default:   return .center
            }
        }

        var body: some View {
            ZStack(alignment: align) {
                // Бэкграунд — изображение (или постер для видео)
                if let u = URL(string: mediaURL), !mediaURL.isEmpty {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle().fill(.white.opacity(0.12))
                                ProgressView().tint(.white)
                            }
                            .frame(height: 220)

                        case .success(let img):
                            img.resizable().scaledToFit()

                        case .failure:
                            ZStack {
                                Rectangle().fill(.white.opacity(0.12))
                                Text("Failed to load").foregroundColor(.white)
                            }
                            .frame(height: 220)

                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    ZStack {
                        Rectangle().fill(.white.opacity(0.12))
                        Text("Pick media…").foregroundColor(.white.opacity(0.7))
                    }
                    .frame(height: 220)
                }

                // Логотип поверх
                if let l = URL(string: logoURL), !logoURL.isEmpty {
                    AsyncImage(url: l) { phase in
                        switch phase {
                        case .empty:
                            Color.clear.frame(width: 1, height: 1)

                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96) // потом можно вынести в слайдер
                                .padding(12)
                                .opacity(opacity)

                        case .failure:
                            EmptyView()

                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}
// MARK: - Body

extension WatermarkScreen {
    var body: some View {
        ZStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    sourceSection
                    logoSection
                    optionsSection
                    livePreviewSection
                    actionsSection
                    if vm.isLoading { loadingPill }
                    resultPreviewSection
                    errorSection
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .brandBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Watermark")
        .sheet(isPresented: $showComposer) {
            PlannerComposer(
                onCreated: { _ in showComposer = false },
                onCancel: { showComposer = false }
            )
        }
        // Pickers (photo/video + logo)
        .sheet(isPresented: $showPhotoLibrary) { photoLibrarySheet }
        .sheet(isPresented: $showPhotoCamera)  { photoCameraSheet.ignoresSafeArea() }
        .sheet(isPresented: $showVideoLibrary) { videoLibrarySheet }
        .sheet(isPresented: $showVideoCamera)  { videoCameraSheet.ignoresSafeArea() }
        .sheet(isPresented: $showLogoLibrary)  { logoLibrarySheet }
        .sheet(isPresented: $showLogoCamera)   { logoCameraSheet.ignoresSafeArea() }
    }
}

// MARK: - Sections

private extension WatermarkScreen {
    @ViewBuilder var sourceSection: some View {
        labeled("Source media") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { showPhotoCamera = true }   label: { Label("Photo Camera", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                    Button { showPhotoLibrary = true }  label: { Label("Photo Library", systemImage: "photo.stack").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                }
                HStack(spacing: 10) {
                    Button { showVideoCamera = true }   label: { Label("Video Camera", systemImage: "video.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                    Button { showVideoLibrary = true }  label: { Label("Video Library", systemImage: "film.stack").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                }
                HStack(spacing: 10) {
                    Button {
                        if let s = UIPasteboard.general.string, s.lowercased().hasPrefix("http") {
                            vm.mediaURL = s
                            vm.sourceNote = "Pasted URL ✅"
                        }
                    } label: { Label("Paste URL", systemImage: "doc.on.clipboard.fill") }
                        .buttonStyle(.bordered)

                    TextField("https://… (image or video url)", text: $vm.mediaURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .foregroundColor(.white)
                }

                if let note = vm.sourceNote {
                    Text(note).font(.footnote).foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder var logoSection: some View {
        labeled("Logo (image)") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { showLogoCamera = true }  label: { Label("Camera",  systemImage: "camera").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                    Button { showLogoLibrary = true } label: { Label("Library", systemImage: "photo").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).tint(.white)
                    Button {
                        if let s = UIPasteboard.general.string, s.lowercased().hasPrefix("http") {
                            vm.logoURL = s
                            vm.logoNote = "Logo URL pasted ✅"
                        }
                    } label: { Label("Paste URL", systemImage: "doc.on.clipboard") }
                        .buttonStyle(.bordered)
                }

                TextField("https://… (logo image url)", text: $vm.logoURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .foregroundColor(.white)

                if let note = vm.logoNote {
                    Text(note).font(.footnote).foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder var optionsSection: some View {
        labeled("Options") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Position").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.8))

                HStack(spacing: 8) {
                    ForEach(["tl","tr","bl","br","c"], id: \.self) { p in
                        Button { vm.position = p } label: {
                            Text(p.uppercased())
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(p == vm.position ? Color.white.opacity(0.22) : Color.white.opacity(0.10)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(p == vm.position ? Color.white.opacity(0.85) : Color.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("Opacity \(String(format: "%.2f", vm.opacity))")
                        .foregroundColor(.white.opacity(0.9))
                    Slider(value: $vm.opacity, in: 0.2...1.0, step: 0.05)
                        .tint(.white)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Live preview
    @ViewBuilder var livePreviewSection: some View {
        labeled("Live preview") {
            WatermarkLivePreview(
                mediaURL: vm.mediaURL,
                logoURL: vm.logoURL,
                position: vm.position,
                opacity: vm.opacity
            )
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions
    @ViewBuilder var actionsSection: some View {
        HStack(spacing: 16) {
            Button {
                Task { await vm.generate() }
            } label: {
                Label("Apply watermark", systemImage: "drop")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(vm.isLoading)

            Button(role: .destructive) {
                vm.mediaURL = ""
                vm.logoURL = ""
                vm.resultURL = nil
                vm.sourceNote = nil
                vm.logoNote = nil
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Result preview
    @ViewBuilder var resultSection: some View {
        if let s = vm.resultURL, let url = absolute(s) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.white)

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.12))
                            ProgressView().tint(.white)
                        }
                        .frame(maxWidth: .infinity)
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.12))
                            Text("Failed to load image")
                                .foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }

                // Quick actions
                HStack(spacing: 12) {
                    Button {
                        if let s = vm.resultURL, let u = absolute(s) {
                            UIPasteboard.general.string = u.absoluteString
                        }
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        vm.resultURL = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        plannerImageURL = vm.resultURL
                        plannerVideoURL = nil
                        plannerCoverURL = nil
                        showComposer = true
                    } label: {
                        Label("Use in Planner", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Errors
    @ViewBuilder var errorSection: some View {
        if let err = vm.errorText {
            Text(err)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Header & helpers
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Watermark")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("Overlay your logo onto photos or videos.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
    }

    private func labeled<T: View>(_ title: String, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
            content()
        }
    }

    private func absolute(_ s: String) -> URL? {
        if let u = URL(string: s), u.scheme != nil { return u }
        var comps = URLComponents(url: API.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = s.hasPrefix("/") ? s : "/" + s
        return comps.url
    }
    private func saveTempImage(_ image: UIImage, preferredExt: String = "jpg", jpegQuality: CGFloat = 0.95) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let name = UUID().uuidString + "." + preferredExt.lowercased()
        let url  = dir.appendingPathComponent(name)

        if preferredExt.lowercased() == "png" {
            guard let data = image.pngData() else {
                throw NSError(domain: "SaveTempImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
            }
            try data.write(to: url, options: .atomic)
        } else {
            guard let data = image.jpegData(compressionQuality: jpegQuality) else {
                throw NSError(domain: "SaveTempImage", code: -2, userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
            }
            try data.write(to: url, options: .atomic)
        }
        return url
    }
}
// MARK: - Loading pill & Sheets
private extension WatermarkScreen {
    @ViewBuilder var loadingPill: some View {
        ProgressView()
            .tint(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
    }

    // Если в body вызвано resultPreviewSection — прокидываем на resultSection
    @ViewBuilder var resultPreviewSection: some View { resultSection }

    // MARK: - Sheets (pickers)
    @ViewBuilder var photoLibrarySheet: some View {
        LibraryPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)                  // -> URL
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.mediaURL = cloud
                    vm.sourceNote = "Photo uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder var photoCameraSheet: some View {
        CameraPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.mediaURL = cloud
                    vm.sourceNote = "Photo captured & uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder var videoLibrarySheet: some View {
        VideoLibraryPicker { url in
            guard let local = url else { return }
            Task {
                do {
                    let cloud = try await CloudinaryUploader.uploadVideo(fileURL: local)
                    vm.mediaURL = cloud
                    vm.sourceNote = "Video uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder var videoCameraSheet: some View {
        VideoCameraPicker { url in
            guard let local = url else { return }
            Task {
                do {
                    let cloud = try await CloudinaryUploader.uploadVideo(fileURL: local)
                    vm.mediaURL = cloud
                    vm.sourceNote = "Video recorded & uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder var logoLibrarySheet: some View {
        LibraryPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.logoURL = cloud
                    vm.logoNote = "Logo uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder var logoCameraSheet: some View {
        CameraPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.logoURL = cloud
                    vm.logoNote = "Logo captured & uploaded ✅"
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }
}
