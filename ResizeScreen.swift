import SwiftUI
import UIKit

@MainActor
final class ResizeVM: ObservableObject {
    @Published var imageURL: String = ""
    @Published var aspect: String = "1:1"
    @Published var maxWidth: Double = 1080
    @Published var fit: String = "cover"          // cover / contain
    @Published var background: String = "black"   // black / white / #RRGGBB

    @Published var isLoading = false
    @Published var resultURL: String?
    @Published var errorText: String?

    func generate() async {
        isLoading = true
        errorText = nil
        resultURL = nil
        defer { isLoading = false }

        guard !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Paste an image URL first."
            return
        }

        do {
            let url = try await MediaAPI.resizeImage(
                url: imageURL,
                aspect: aspect,
                maxWidth: Int(maxWidth),
                fit: fit,
                background: background
            )
            resultURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct ResizeScreen: View {
    @StateObject private var vm = ResizeVM()
    @State private var showComposer = false
    @State private var plannerImageURL: String?
    @State private var plannerVideoURL: String?
    @State private var plannerCoverURL: String?
    
    // Photo pickers
    @State private var showPhotoLibrary = false
    @State private var showPhotoCamera = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    // SOURCE
                    Group {
                        labeled("Source image") {
                            HStack(spacing: 10) {
                                Button {
                                    if let s = UIPasteboard.general.string, s.lowercased().hasPrefix("http") {
                                        vm.imageURL = s
                                    }
                                } label: {
                                    Label("Paste URL", systemImage: "doc.on.clipboard.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)

                                TextField("https://… (image url)", text: $vm.imageURL, axis: .vertical)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            }
                        }
                        // PICKERS
                        labeled("Pick") {
                            HStack(spacing: 10) {
                                Button {
                                    showPhotoLibrary = true
                                } label: {
                                    Label("Library", systemImage: "photo.on.rectangle")
                                }
                                .buttonStyle(.bordered).tint(.white)

                                Button {
                                    showPhotoCamera = true
                                } label: {
                                    Label("Camera", systemImage: "camera.fill")
                                }
                                .buttonStyle(.bordered).tint(.white)

                                Button {
                                    if let s = UIPasteboard.general.string, s.lowercased().hasPrefix("http") {
                                        vm.imageURL = s
                                    }
                                } label: {
                                    Label("Paste URL", systemImage: "doc.on.clipboard")
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        labeled("Aspect ratio") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(["1:1","4:5","9:16","16:9","3:4"], id: \.self) { a in
                                        Button {
                                            vm.aspect = a
                                        } label: {
                                            Text(a)
                                                .font(.footnote.weight(.semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(vm.aspect == a ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(vm.aspect == a ? Color.white.opacity(0.85) : Color.white.opacity(0.18))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        labeled("Max width: \(Int(vm.maxWidth)) px") {
                            Slider(value: $vm.maxWidth, in: 320...2160, step: 10)
                                .tint(.white)
                        }

                        labeled("Fit mode") {
                            Picker("", selection: $vm.fit) {
                                Text("Cover").tag("cover")
                                Text("Contain").tag("contain")
                            }
                            .pickerStyle(.segmented)
                            .tint(.white.opacity(0.9))
                            .colorMultiply(.black)
                        }

                        if vm.fit == "contain" {
                            labeled("Background") {
                                TextField("black / white / #RRGGBB", text: $vm.background)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // LIVE PREVIEW
                    labeled("Live preview") {
                        ResizeLivePreview(
                            imageURL: vm.imageURL,
                            aspect: vm.aspect,
                            fit: vm.fit,
                            background: vm.background
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)

                    // ACTIONS
                    HStack(spacing: 16) {
                        Button {
                            Task { await vm.generate() }
                        } label: {
                            Label("Resize", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(vm.isLoading)

                        Button(role: .destructive) {
                            vm.imageURL = ""
                            vm.resultURL = nil
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 20)

                    // LOADING
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }

                    // PREVIEW
                    if let s = vm.resultURL, let url = absolute(s) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.white)

                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                                        ProgressView().tint(.white)
                                    }.frame(height: 220)
                                case .success(let img):
                                    img.resizable().scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2)))
                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                                        Text("Failed to load").foregroundColor(.white)
                                    }.frame(height: 220)
                                @unknown default: EmptyView()
                                }
                            }

                            // ↓↓↓ Кнопки действий для результата
                            HStack(spacing: 12) {
                                Button {
                                    if let s = vm.resultURL, let u = absolute(s) {
                                        UIPasteboard.general.string = u.absoluteString
                                    }
                                } label: {
                                    Label("Copy URL", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    // заполняем поля для PlannerComposer
                                    plannerImageURL = vm.resultURL       // это картинка из resize
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

                    // ERRORS
                    if let err = vm.errorText {
                        Text(err)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .brandBackground() // новый фон
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Resize")
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
        .sheet(isPresented: $showPhotoLibrary) {
            LibraryPicker { image in
                guard let img = image else { return }
                Task {
                    do {
                        let tmp = try saveTempImage(img)
                        let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                        vm.imageURL = cloud
                    } catch {
                        vm.errorText = error.localizedDescription
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoCamera) {
            CameraPicker { image in
                guard let img = image else { return }
                Task {
                    do {
                        let tmp = try saveTempImage(img)
                        let cloud = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                        vm.imageURL = cloud
                    } catch {
                        vm.errorText = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Helper
    private func saveTempImage(_ image: UIImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "ResizeScreen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        try jpegData.write(to: tempFile)
        return tempFile
    }
    // MARK: - Bits

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resize")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("Change aspect ratio, scale, and background.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func labeled<T: View>(_ title: String, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            content()
        }
    }

    private func absolute(_ pathOrURL: String) -> URL? {
        if let u = URL(string: pathOrURL), u.scheme != nil { return u }
        var comps = URLComponents(url: API.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = pathOrURL.hasPrefix("/") ? pathOrURL : "/" + pathOrURL
        return comps.url
    }
}
    
// MARK: - Live preview pieces
private struct ResizeLivePreview: View {
    let imageURL: String
    let aspect: String      // "1:1", "4:5", "9:16", "16:9", "3:4"
    let fit: String         // "cover" / "contain"
    let background: String  // "black"/"white"/"#RRGGBB"
    private var aspectRatio: CGFloat {
        switch aspect {
        case "1:1":  return 1
        case "4:5":  return 4.0/5.0
        case "9:16": return 9.0/16.0
        case "16:9": return 16.0/9.0
        case "3:4":  return 3.0/4.0
        default:     return 1
        }
    }

    private var bgColor: Color {
        switch background.lowercased() {
        case "black":
            return .black.opacity(0.35)
        case "white":
            return .white.opacity(0.35)
        default:
            // поддержка #RRGGBB / #RRGGBBAA
            return Color(hex: background).opacity(0.35)
        }
    }
    
    private var isCover: Bool { fit.lowercased() == "cover" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bgColor)

            if let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bgColor)
                            ProgressView().tint(.white)
                        }
                    case .success(let img):
                        img.resizable()
                            .modifier(ScaledMode(isCover: isCover))
                            .clipped()
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.12))
                            Text("Failed to load image").foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.12))
                    Text("Paste an image URL to preview").foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    private struct ScaledMode: ViewModifier {
        let isCover: Bool
        func body(content: Content) -> some View {
            isCover ? AnyView(content.scaledToFill())
                    : AnyView(content.scaledToFit())
        }
    }
}
