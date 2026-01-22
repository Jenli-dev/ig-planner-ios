import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct FiltersScreen: View {
    @StateObject private var vm = VideoFilterVM()

    @State private var videoURL = "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4"
    @State private var preset = "cinematic"
    @State private var intensity: Double = 0.7
    @State private var thumbAt: Double = 1.0
    @State private var showComposer = false
    @State private var plannerImageURL: String?
    @State private var plannerVideoURL: String?
    @State private var plannerCoverURL: String?
    
    // Video source selection
    @State private var showVideoLibrary = false
    @State private var showVideoCamera = false
    @State private var isUploadingVideo = false
    @State private var selectedVideoURL: URL?

    // alert state
    @State private var showAlert = false
    @State private var alertText = ""

    private let presets = [
        "cinematic","warm","cool","boost","teal_orange",
        "pastel","matte","hdr","sepia","clarity","grain","fade_soft","deband","b&w"
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Group {
                        Labeled("Source video")
                        
                        // Source selection buttons
                        HStack(spacing: 10) {
                            Button {
                                showVideoLibrary = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Library")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            Button {
                                showVideoCamera = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Camera")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.bottom, 8)
                        
                        Labeled("Or paste video URL")
                        URLField(text: $videoURL)

                        HStack(alignment: .center) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presets, id: \.self) { p in
                                        Button {
                                            preset = p
                                        } label: {
                                            Text(p)
                                                .font(.footnote.weight(.semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(preset == p ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(preset == p ? Color.white.opacity(0.85) : Color.white.opacity(0.18), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            Spacer()

                            Text("Intensity \(intensity, specifier: "%.2f")")
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.leading, 8)
                        }

                        Slider(value: $intensity, in: 0...1)
                            .tint(.blue)
                    }
                    .padding(.horizontal, 20)
                    // PREVIEW (кадр из видео)
                    VStack(alignment: .leading, spacing: 8) {
                        Labeled("Preview")

                        VStack(alignment: .leading, spacing: 10) {
                            if let u = URL(string: videoURL) {
                                VideoThumbnailView(url: u, timeSec: thumbAt)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                                    Text("Paste a valid video URL").foregroundColor(.white.opacity(0.7))
                                }
                                .frame(height: 220)
                            }

                            HStack {
                                Text("at \(thumbAt, specifier: "%.2f")s")
                                    .foregroundColor(.white.opacity(0.9))
                                Slider(value: $thumbAt, in: 0...10, step: 0.05)
                                    .tint(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 14) {
                        Button {
                            Task { await vm.runFilter(for: videoURL, preset: preset, intensity: intensity) }
                        } label: {
                            Label("Apply filter", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isLoading)

                        Button(role: .destructive) {
                            vm.reset()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(vm.isLoading && vm.outputURL == nil)
                    }
                    .padding(.horizontal, 20)

                    if vm.isLoading || vm.progress != nil {
                        ProgressRow(progress: vm.progress)
                            .padding(.horizontal, 20)
                    }

                    if let out = vm.outputURL, let url = absolute(out) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result").font(.headline).foregroundColor(.white)
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 280)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }

                    Spacer(minLength: 90)
                }
            }

            if (vm.isLoading && vm.outputURL == nil) || isUploadingVideo {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    if isUploadingVideo {
                        Text("Uploading video...")
                            .foregroundColor(.white)
                            .font(.footnote)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 8)
            }
        }
        .brandBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar) 

        // ловим ошибки из VM и показываем алерт
        .onChange(of: vm.lastError) { _, newValue in
            if let t = newValue {
                alertText = t
                showAlert = true
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { showAlert = false }
        } message: {
            Text(alertText)
        }
        .sheet(isPresented: $showVideoLibrary) {
            VideoLibraryPicker { url in
                if let url = url {
                    selectedVideoURL = url
                    Task {
                        await uploadVideoToServer(url: url)
                    }
                }
            }
        }
        .sheet(isPresented: $showVideoCamera) {
            VideoCameraPicker { url in
                if let url = url {
                    selectedVideoURL = url
                    Task {
                        await uploadVideoToServer(url: url)
                    }
                }
            }
        }
    }
    
    // MARK: - Video Upload
    @MainActor
    private func uploadVideoToServer(url: URL) async {
        isUploadingVideo = true
        defer { isUploadingVideo = false }
        
        do {
            // Read video data
            let videoData = try Data(contentsOf: url)
            
            // Create multipart form data
            var request = URLRequest(url: API.url("/uploads/video"))
            request.httpMethod = "POST"
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorText = String(data: data, encoding: .utf8) ?? "Upload failed"
                throw NSError(domain: "Upload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            }
            
            struct UploadResponse: Decodable {
                let ok: Bool
                let video_url: String?
            }
            
            let result = try JSONDecoder().decode(UploadResponse.self, from: data)
            
            if let videoURLString = result.video_url {
                videoURL = videoURLString
            } else {
                throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video URL in response"])
            }
        } catch {
            alertText = "Failed to upload video: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private var header: some View {
        Text("Filters")
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }
}

// MARK: - Small UI helpers

private struct Labeled: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white.opacity(0.9))
    }
}

private struct ProgressRow: View {
    let progress: Int?
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white)
            Text(progress != nil ? "Encoding \(progress!)%" : "Preparing…")
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct URLField: View {
    @Binding var text: String
    var body: some View {
        TextField("https://…", text: $text, axis: .vertical)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .foregroundColor(.white)
            .padding(10)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.18)))
    }
}

// Абсолютный URL из относительного /static/…
fileprivate func absolute(_ pathOrURL: String) -> URL? {
    if let u = URL(string: pathOrURL), u.scheme != nil { return u }
    var comps = URLComponents(url: API.baseURL, resolvingAgainstBaseURL: false)!
    comps.path = pathOrURL.hasPrefix("/") ? pathOrURL : "/" + pathOrURL
    return comps.url
}
private struct VideoThumbnailView: View {
    let url: URL
    let timeSec: Double

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                    ProgressView().tint(.white)
                }
                .frame(height: 220)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                    Text("No preview").foregroundColor(.white.opacity(0.7))
                }
                .frame(height: 220)
            }
        }
        .task(id: "\(url.absoluteString)-\(timeSec)") {
            await generate()
        }
    }

    @MainActor
    private func generate() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let asset: AVAsset
            if #available(iOS 18.0, *) {
                asset = AVURLAsset(url: url)
            } else {
                asset = AVAsset(url: url)
            }
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceAfter = .zero
            gen.requestedTimeToleranceBefore = .zero

            let cm = CMTime(seconds: timeSec, preferredTimescale: 600)
            let cg = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CGImage, Error>) in
                gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: cm)]) { _, img, _, res, err in
                    if let e = err { cont.resume(throwing: e); return }
                    if let i = img, res == .succeeded { cont.resume(returning: i); return }
                    cont.resume(throwing: NSError(domain: "Thumb", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create frame"]))
                }
            }
            image = UIImage(cgImage: cg)
        } catch {
            image = nil
        }
    }
}
