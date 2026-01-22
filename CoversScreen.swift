import SwiftUI
import PhotosUI
import UIKit
import Photos

// MARK: - ViewModel
@MainActor
final class CoversVM: ObservableObject {
    @Published var videoURL: String = ""
    @Published var at: Double = 1.0

    // overlay
    @Published var title: String = ""
    @Published var position: String = "bottom" // "top" | "bottom"
    @Published var padding: Double = 32
    @Published var fontName: String = ""       // опционально: Inter / NotoSans и т.п.

    // UI/State
    @Published var isLoading = false
    @Published var coverURL: String?
    @Published var errorText: String?
    @Published var sourceNote: String?         // "Uploaded to Cloudinary", "Validated" и т.п.

    @Published var fonts: [FontItem] = []
    @Published var isFontsLoading = false

    enum CoverPreset: String, CaseIterable {
        case minimal = "Minimal"
        case bold    = "Bold"
        case solid   = "Solid"
        case frameTitle = "Frame+Title"
    }
    @Published var selectedPreset: CoverPreset = .minimal

    func applyPreset(_ p: CoverPreset) {
        selectedPreset = p
        switch p {
        case .minimal:
            title = ""
            position = "bottom"
            padding = 24
            fontName = ""
        case .bold:
            position = "bottom"
            padding = 32
            if title.isEmpty { title = "Your catchy headline" }
            fontName = "Inter"
        case .solid:
            position = "top"
            padding = 28
            if title.isEmpty { title = "Title on solid bg" }
        case .frameTitle:
            position = "bottom"
            padding = 36
            if title.isEmpty { title = "Episode 12 — Quick Tips" }
        }
    }

    @Published var frameURL: String?   // быстрый превью-кадр (без оверлея)

    func grabFrame() async {
        guard !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Paste or upload a video first."
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            // Получаем только кадр (без текста) для быстрого предпросмотра
            let url = try await MediaAPI.reelCover(videoURL: videoURL, at: at, overlay: nil)
            frameURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    func validateSourceURL() async {
        guard !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            _ = try await MediaAPI.validate(url: videoURL, type: "video", target: "REELS")
            sourceNote = "Source validated ✅"
        } catch {
            sourceNote = nil
            errorText = error.localizedDescription
        }
    }
    func generate() async {
        isLoading = true
        errorText = nil
        coverURL = nil
        defer { isLoading = false }

        guard !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Paste a video URL first."
            return
        }

        do {
            var overlay: [String: Any]? = nil
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var o: [String: Any] = [
                    "text": title,
                    "pos": position,
                    "padding": Int(padding)
                ]
                if !fontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    o["font"] = fontName
                }
                overlay = o
            }

            let url = try await MediaAPI.reelCover(
                videoURL: videoURL,
                at: at,
                overlay: overlay
            )
            coverURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    func loadFontsIfNeeded(force: Bool = false) async {
        guard force || fonts.isEmpty else { return }
        isFontsLoading = true
        defer { isFontsLoading = false }
        do {
            let list = try await UtilAPI.fonts()
            self.fonts = list
            if self.fontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let first = list.first {
                self.fontName = first.name
            }
        } catch {
            self.errorText = error.localizedDescription
        }
    }
}

// MARK: - Screen

struct CoversScreen: View {
    @StateObject private var vm = CoversVM()

    // pickers
    @State private var showVideoCamera = false
    @State private var showVideoLibrary = false
    @State private var showPhotoCamera = false
    @State private var showPhotoLibrary = false

    // alerts
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    
    @State private var showComposer = false
    @State private var plannerImageURL: String?
    @State private var plannerVideoURL: String?
    @State private var plannerCoverURL: String?
    var body: some View {
        ZStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    sourceSection
                    frameSection
                    presetsSection
                    overlaySection
                    generateButtonsSection

                    if vm.isLoading { loadingPill }

                    liveFramePreviewSection
                    finalPreviewSection
                    errorSection
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .brandBackground()                      // ← добавили единый бренд-фон
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Covers")
        .task { await vm.loadFontsIfNeeded() }
        .sheet(isPresented: $showVideoLibrary) { videoLibrarySheet }
        .sheet(isPresented: $showVideoCamera)  { videoCameraSheet.ignoresSafeArea() }
        .sheet(isPresented: $showPhotoLibrary) { photoLibrarySheet }
        .sheet(isPresented: $showPhotoCamera)  { photoCameraSheet.ignoresSafeArea() }
        .sheet(isPresented: $showComposer) {
            PlannerComposer(
                onCreated: { _ in
                    // черновик/пост создан
                    showComposer = false
                },
                onCancel: {
                    // пользователь закрыл композер
                    showComposer = false
                }
            )
        }
    }
    @ViewBuilder private var overlaySection: some View {
        Group {
            labeled("Overlay title (optional)") {
                TextField("Your title…", text: $vm.title)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Position").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $vm.position) {
                        Text("Bottom").tag("bottom")
                        Text("Top").tag("top")
                    }
                    .pickerStyle(.segmented)
                    .tint(.white.opacity(0.85))
                    .colorMultiply(.black)
                }

                VStack(alignment: .leading) {
                    Text("Padding").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.8))
                    Slider(value: $vm.padding, in: 8...64, step: 1).tint(.white)
                }
            }

            labeled("Font") {
                HStack {
                    Menu {
                        if vm.isFontsLoading {
                            Text("Loading…")
                        } else {
                            ForEach(vm.fonts, id: \.self) { f in
                                Button(f.display ?? f.name) { vm.fontName = f.name }
                            }
                        }
                        Divider()
                        Button {
                            Task { await vm.loadFontsIfNeeded(force: true) }
                        } label: {
                            Label("Refresh list", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedFontTitle())
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    if vm.isFontsLoading {
                        ProgressView().tint(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    @ViewBuilder private var sourceSection: some View {
        Group {
            labeled("Source") {
                VStack(spacing: 10) {
                    // Video buttons
                    HStack(spacing: 10) {
                        Button { showVideoCamera = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                Text("Video")
                                    .font(.caption2)
                                Text("Camera")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.white)

                        Button { showVideoLibrary = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "film.stack")
                                Text("Video")
                                    .font(.caption2)
                                Text("Library")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.white)
                    }
                    
                    // Photo buttons
                    HStack(spacing: 10) {
                        Button { showPhotoCamera = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                Text("Photo")
                                    .font(.caption2)
                                Text("Camera")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.white)

                        Button { showPhotoLibrary = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photo")
                                    .font(.caption2)
                                Text("Library")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.white)
                    }

                    Button {
                        if let s = UIPasteboard.general.string, s.lowercased().hasPrefix("http") {
                            vm.videoURL = s
                            Task { await vm.validateSourceURL() }
                        }
                    } label: {
                        Label("Paste URL", systemImage: "doc.on.clipboard.fill")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField("https://… (video or image url)", text: $vm.videoURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .foregroundColor(.white)
                        .onSubmit { Task { await vm.validateSourceURL() } }

                    if let note = vm.sourceNote {
                        Text(note).font(.footnote).foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var frameSection: some View {
        Group {
            labeled("Frame (sec)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: "at %.2fs", vm.at))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Button {
                            Task { await vm.grabFrame() }
                        } label: {
                            Label("Grab frame", systemImage: "square.on.square.intersection.dashed")
                        }
                        .buttonStyle(.bordered)
                    }
                    Slider(value: $vm.at, in: 0...10, step: 0.05).tint(.white)
                }
            }
        }
        .padding(.horizontal, 20)
    }
                           
    @ViewBuilder private var generateButtonsSection: some View {
        HStack(spacing: 16) {
            Button {
                Task { await vm.generate() }
            } label: {
                Label("Generate cover", systemImage: "rectangle.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(vm.isLoading)

            Button(role: .destructive) {
                vm.title = ""
                vm.coverURL = nil
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
    }
    @ViewBuilder private var loadingPill: some View {
        ProgressView()
            .tint(.white)
            .padding()
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    @ViewBuilder private var liveFramePreviewSection: some View {
        if let s = vm.frameURL, let url = absolute(s) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Frame preview (live overlay)")
                    .font(.headline)
                    .foregroundColor(.white)

                CoverLivePreview(
                    imageURL: url,
                    title: vm.title,
                    position: vm.position,
                    padding: vm.padding,
                    fontName: vm.fontName
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
    }
    @ViewBuilder private var finalPreviewSection: some View {
        if let s = vm.coverURL, let url = absolute(s) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.white)

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.1))
                            ProgressView().tint(.white)
                        }
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.1))
                            Text("Failed to load image").foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                // Export buttons
                HStack(spacing: 12) {
                    Button {
                        if let s = vm.coverURL, let u = absolute(s) {
                            UIPasteboard.general.string = u.absoluteString
                        }
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            do {
                                try await saveImageToPhotos(from: vm.coverURL)
                                saveMessage = "Saved to Photos ✅"
                            } catch {
                                saveMessage = error.localizedDescription
                            }
                            showSaveAlert = true
                        }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        plannerCoverURL = vm.coverURL
                        plannerImageURL = nil
                        plannerVideoURL = nil
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
            .alert("Info", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }
    @ViewBuilder private var errorSection: some View {
        if let err = vm.errorText {
            Text(err)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
        }
    }
    @ViewBuilder private var videoLibrarySheet: some View {
        VideoLibraryPicker { pickedURL in
            guard let localURL = pickedURL else { return }
            Task {
                do {
                    let cloud = try await CloudinaryUploader.uploadVideo(fileURL: localURL)
                    vm.videoURL = cloud
                    vm.sourceNote = "Video uploaded ✅"
                    await vm.validateSourceURL()
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder private var videoCameraSheet: some View {
        VideoCameraPicker { recordedURL in
            guard let localURL = recordedURL else { return }
            Task {
                do {
                    let cloud = try await CloudinaryUploader.uploadVideo(fileURL: localURL)
                    vm.videoURL = cloud
                    vm.sourceNote = "Recorded & uploaded ✅"
                    await vm.validateSourceURL()
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }
    
    @ViewBuilder private var photoLibrarySheet: some View {
        LibraryPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.videoURL = cloud
                    vm.sourceNote = "Photo uploaded ✅"
                    await vm.validateSourceURL()
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }
    
    @ViewBuilder private var photoCameraSheet: some View {
        CameraPicker { image in
            guard let img = image else { return }
            Task {
                do {
                    let tmp = try saveTempImage(img)
                    let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    vm.videoURL = cloud
                    vm.sourceNote = "Photo captured & uploaded ✅"
                    await vm.validateSourceURL()
                } catch {
                    vm.errorText = error.localizedDescription
                }
            }
        }
    }
    
    private func saveTempImage(_ image: UIImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "CoversScreen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        try jpegData.write(to: tempFile)
        return tempFile
    }
    
    @ViewBuilder private var presetsSection: some View {
        Group {
            labeled("Templates") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CoversVM.CoverPreset.allCases, id: \.self) { p in
                            Button { vm.applyPreset(p) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(p.rawValue)
                                        .font(.footnote.weight(.semibold))
                                    Text(p == vm.selectedPreset ? "Selected" : "Tap to apply")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(width: 130, height: 64, alignment: .leading)
                                .background(
                                    Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            p == vm.selectedPreset
                                            ? Color.white.opacity(0.9)
                                            : Color.white.opacity(0.18),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Bits (внутри struct CoversScreen, но вне body)
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Covers")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("Grab a frame from your video and optionally add a title.")
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
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

    private func selectedFontTitle() -> String {
        if let f = vm.fonts.first(where: { $0.name == vm.fontName }) {
            return f.display ?? f.name
        }
        return vm.fontName.isEmpty ? "System default" : vm.fontName
    }

    /// Абсолютный URL для путей вида "/static/out/..."
    private func absolute(_ pathOrURL: String) -> URL? {
        if let u = URL(string: pathOrURL), u.scheme != nil { return u }
        var comps = URLComponents(url: API.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = pathOrURL.hasPrefix("/") ? pathOrURL : "/" + pathOrURL
        return comps.url
    }

    // MARK: - Live overlay preview pieces
    private struct CoverLivePreview: View {
        let imageURL: URL
        let title: String
        let position: String   // "top" | "bottom"
        let padding: Double
        let fontName: String

        var body: some View {
            ZStack(alignment: position == "top" ? .top : .bottom) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.1))
                            ProgressView().tint(.white)
                        }
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.1))
                            Text("Failed to load").foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }

                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    OverlayTitleBar(
                        title: title,
                        padding: padding,
                        font: mappedFont(fontName)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }

        private func mappedFont(_ name: String) -> Font {
            let n = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if n.contains("inter") { return .system(.title3, design: .rounded).weight(.semibold) }
            if n.contains("noto")  { return .system(.title3, design: .default).weight(.semibold) }
            if n.contains("arial") { return .system(.title3, design: .default).weight(.semibold) }
            return .system(.title3, design: .rounded).weight(.semibold)
        }
    }
    private struct OverlayTitleBar: View {
        let title: String
        let padding: Double
        let font: Font

        var body: some View {
            Text(title)
                .font(font)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .lineLimit(3)
                .padding(.horizontal, max(12, padding))
                .padding(.vertical, max(8, padding * 0.5))
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
} // <-- конец struct CoversScreen

// MARK: - Save helper (вне struct)
private func saveImageToPhotos(from urlString: String?) async throws {
    guard
        let s = urlString,
        let url = URL(string: s)
    else {
        throw NSError(
            domain: "SaveImage",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
        )
    }

    // Скачиваем данные
    let (data, resp) = try await URLSession.shared.data(from: url)
    guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        throw NSError(
            domain: "SaveImage",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Download failed"]
        )
    }
    guard let img = UIImage(data: data) else {
        throw NSError(
            domain: "SaveImage",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "Image decode failed"]
        )
    }

    // Сохраняем в фото
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                cont.resume(throwing: NSError(
                    domain: "SaveImage",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Photos permission denied"]
                ))
                return
            }

            var localId: String?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest.creationRequestForAsset(from: img)
                localId = req.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { success, error in
                if let e = error {
                    cont.resume(throwing: e)
                    return
                }
                guard success, localId != nil else {
                    cont.resume(throwing: NSError(
                        domain: "SaveImage",
                        code: -5,
                        userInfo: [NSLocalizedDescriptionKey: "Save failed"]
                    ))
                    return
                }
                cont.resume()
            })
        }
    }
}
