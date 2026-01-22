import SwiftUI
import UIKit
import PhotosUI
import Vision

// MARK: - Photo Upload Flow

enum PhotoUploadStep: Hashable {
    case photoSelection
    case instructions
    case genderSelection
    case photoReview
}

struct PhotoUploadFlowView: View {
    @Binding var selectedImages: [String]
    @Binding var selectedGender: AvatarGender?
    let onComplete: (AvatarGender?) -> Void
    
    @State private var navigationPath = NavigationPath()
    @State private var localImages: [UIImage] = []
    @State private var isUploading = false
    @State private var uploadedCount = 0
    @State private var uploadComplete = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            PhotoSelectionView(
                localImages: $localImages,
                isUploading: $isUploading,
                uploadedCount: $uploadedCount,
                onContinue: {
                    navigationPath.append(PhotoUploadStep.instructions)
                }
            )
            .navigationDestination(for: PhotoUploadStep.self) { step in
                switch step {
                case .instructions:
                    InstructionsView {
                        navigationPath.append(PhotoUploadStep.genderSelection)
                    }
                case .genderSelection:
                    GenderSelectionView(
                        selectedGender: $selectedGender,
                        onNext: {
                            navigationPath.append(PhotoUploadStep.photoReview)
                        }
                    )
                case .photoReview:
                    PhotoReviewView(
                        localImages: $localImages,
                        selectedGender: selectedGender,
                        isUploading: $isUploading,
                        uploadComplete: $uploadComplete,
                        onComplete: { gender in
                            // Upload images asynchronously
                            uploadImages { urls in
                                // Check if upload was successful
                                guard urls.count >= 15 else {
                                    // Show error or stay on screen
                                    print("⚠️ Failed to upload enough photos. Uploaded: \(urls.count), needed: 15")
                                    // Don't dismiss - let user retry or add more photos
                                    return
                                }
                                
                                // Update selectedImages binding first
                                selectedImages = urls
                                
                                // Then call onComplete with gender
                                onComplete(gender)
                                
                                // Mark upload as complete, then dismiss after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    uploadComplete = true
                                    dismiss()
                                }
                            }
                        },
                        onAddMorePhotos: {
                            // Navigate back to photo selection
                            navigationPath.removeLast()
                            navigationPath.append(PhotoUploadStep.photoSelection)
                        }
                    )
                case .photoSelection:
                    PhotoSelectionView(
                        localImages: $localImages,
                        isUploading: $isUploading,
                        uploadedCount: $uploadedCount,
                        onContinue: {
                            navigationPath.append(PhotoUploadStep.instructions)
                        }
                    )
                }
            }
        }
        .brandBackground()
    }
    
    private func uploadImages(completion: @escaping ([String]) -> Void) {
        guard !localImages.isEmpty else {
            completion([])
            return
        }
        
        isUploading = true
        uploadedCount = 0
        
        Task {
            var urls: [String] = []
            var errors: [String] = []
            
            for (index, image) in localImages.enumerated() {
                do {
                    let tmp = try saveTempImage(image)
                    let url = try await CloudinaryUploader.uploadImage(fileURL: tmp)
                    urls.append(url)
                    uploadedCount += 1
                    print("✅ Uploaded photo \(index + 1)/\(localImages.count)")
                } catch {
                    let errorMsg = "Failed to upload photo \(index + 1): \(error.localizedDescription)"
                    errors.append(errorMsg)
                    print("❌ \(errorMsg)")
                }
            }
            
            await MainActor.run {
                isUploading = false
                
                if !errors.isEmpty {
                    print("⚠️ Upload completed with \(errors.count) errors. Total uploaded: \(urls.count)/\(localImages.count)")
                } else {
                    print("✅ All photos uploaded successfully: \(urls.count) photos")
                }
                
                completion(urls)
            }
        }
    }
    
    private func saveTempImage(_ image: UIImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "PhotoUploadFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        try jpegData.write(to: tempFile)
        return tempFile
    }
}

// MARK: - Photo Selection Screen

struct PhotoSelectionView: View {
    @Binding var localImages: [UIImage]
    @Binding var isUploading: Bool
    @Binding var uploadedCount: Int
    let onContinue: () -> Void
    
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text("Select Photos")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Selection buttons
                    HStack(spacing: 12) {
                        Button {
                            showPhotoLibrary = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Select Photos")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("Camera")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Selected images grid (3x3)
                    if !localImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Added: \(localImages.count) photos")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                .init(.flexible()),
                                .init(.flexible()),
                                .init(.flexible())
                            ], spacing: 12) {
                                ForEach(Array(localImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                        
                                        Button {
                                            localImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                Button {
                                    onContinue()
                                } label: {
                                    Text("Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [.pink, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(localImages.count < 15)
                                .opacity(localImages.count < 15 ? 0.6 : 1.0)
                                
                                Button {
                                    showPhotoLibrary = true
                                } label: {
                                    Text("Add more photo")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.pink.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .brandBackground()
        .navigationTitle("Select Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotos,
            maxSelectionCount: 50,
            matching: .images
        )
        .onChange(of: selectedPhotos) { oldValue, newItems in
            Task {
                var newImages: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        newImages.append(image)
                    }
                }
                await MainActor.run {
                    localImages.append(contentsOf: newImages)
                    // Clear selection after processing
                    selectedPhotos = []
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let image = image {
                    localImages.append(image)
                }
            }
        }
    }
}

// MARK: - Instructions Screen

struct InstructionsView: View {
    let onNext: () -> Void
    
    // 2 example photos with X marks - bad examples
    private var badPhotoExamples: [String] {
        [
            "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=400&h=400&fit=crop", // group photo
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces&q=20&blur=50" // blurry/low quality
        ]
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    photoExamplesSection
                    instructionsList
                    recommendationsSection
                    Spacer()
                    nextButton
                }
            }
        }
        .brandBackground()
        .navigationTitle("Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    private var titleSection: some View {
        Text("Please avoid uploading photos where")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }
    
    private var photoExamplesSection: some View {
        HStack(spacing: 12) {
            ForEach(Array(badPhotoExamples.enumerated()), id: \.offset) { index, urlString in
                badPhotoExampleView(urlString: urlString)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func badPhotoExampleView(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                ZStack {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderView
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .opacity(0.5)
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 3)
                )
            } else {
                ZStack {
                    placeholderView
                    Image(systemName: "xmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.red)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 3)
                )
            }
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.12))
            .frame(height: 140)
    }
    
    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            InstructionItem(text: "There's more than one person in the frame")
            InstructionItem(text: "The angle doesn't show your face clearly")
            InstructionItem(text: "Your face appears too small")
            InstructionItem(text: "The lighting or composition is poor")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("To achieve the best results, do not use")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            RecommendationItem(text: "Photos from social networks — they're often compressed and lose detail")
            RecommendationItem(text: "Low-resolution photos — your avatar might not look as sharp")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var nextButton: some View {
        Button {
            onNext()
        } label: {
            Text("Next")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

struct InstructionItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.red)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            Spacer(minLength: 0)
        }
    }
}

struct RecommendationItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Gender Selection Screen

struct GenderSelectionView: View {
    @Binding var selectedGender: AvatarGender?
    let onNext: () -> Void
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What gender is your avatar?")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    Text("We need this information to start creating your individual look")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                    
                    // Gender cards with real photos
                    VStack(spacing: 16) {
                        ForEach(AvatarGender.allCases, id: \.self) { gender in
                            Button {
                                selectedGender = gender
                            } label: {
                                HStack(spacing: 16) {
                                    // Gender photo
                                    let photoURL = gender == .woman 
                                        ? "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=faces"
                                        : "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&h=200&fit=crop&crop=faces"
                                    
                                    if let url = URL(string: photoURL) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.12))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 40))
                                                            .foregroundColor(.white.opacity(0.6))
                                                    )
                                            case .success(let img):
                                                img
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.12))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 40))
                                                            .foregroundColor(.white.opacity(0.6))
                                                    )
                                            @unknown default:
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.12))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 40))
                                                            .foregroundColor(.white.opacity(0.6))
                                                    )
                                            }
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.white.opacity(0.6))
                                            )
                                    }
                                    
                                    Text(gender.rawValue)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if selectedGender == gender {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.pink)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedGender == gender ? Color.white.opacity(0.2) : Color.white.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedGender == gender ? Color.pink : Color.white.opacity(0.2), lineWidth: selectedGender == gender ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Next button
                    Button {
                        onNext()
                    } label: {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selectedGender == nil)
                    .opacity(selectedGender == nil ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .brandBackground()
        .navigationTitle("Gender Selection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Photo Review Screen

struct PhotoReviewView: View {
    @Binding var localImages: [UIImage]
    let selectedGender: AvatarGender?
    @Binding var isUploading: Bool
    @Binding var uploadComplete: Bool
    let onComplete: (AvatarGender?) -> Void
    let onAddMorePhotos: (() -> Void)?
    
    @State private var photoIssues: [Int: PhotoIssue] = [:] // Index -> issue
    @State private var isCheckingPhotos = false
    
    init(
        localImages: Binding<[UIImage]>,
        selectedGender: AvatarGender?,
        isUploading: Binding<Bool>,
        uploadComplete: Binding<Bool>,
        onComplete: @escaping (AvatarGender?) -> Void,
        onAddMorePhotos: (() -> Void)? = nil
    ) {
        self._localImages = localImages
        self.selectedGender = selectedGender
        self._isUploading = isUploading
        self._uploadComplete = uploadComplete
        self.onComplete = onComplete
        self.onAddMorePhotos = onAddMorePhotos
    }
    
    enum PhotoIssue {
        case noFace
        case multipleFaces
        case tooSmall
        case tooLarge
        case poorQuality
        
        var description: String {
            switch self {
            case .noFace: return "No face detected"
            case .multipleFaces: return "Multiple faces detected"
            case .tooSmall: return "Photo is too small"
            case .tooLarge: return "Photo may be compressed"
            case .poorQuality: return "Poor quality"
            }
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text("Review Your Photos")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Description
                    Text("Check your photos. Photos with warnings may not work well. Remove any that don't meet the requirements.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                    
                    // Photo count and status
                    if !localImages.isEmpty {
                        let goodPhotosCount = localImages.count - photoIssues.count
                        let needsMorePhotos = goodPhotosCount < 15
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Added: \(localImages.count) photos")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                if !photoIssues.isEmpty {
                                    Text("• \(photoIssues.count) with warnings")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            if needsMorePhotos {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.yellow)
                                    Text("You need at least 15 good photos. Currently: \(goodPhotosCount) good photos")
                                        .font(.subheadline)
                                        .foregroundColor(.yellow)
                                }
                                .padding(.top, 4)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                    Text("\(goodPhotosCount) good photos ready")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    
                    // Checking status
                    if isCheckingPhotos {
                        HStack {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Analyzing photos...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Photos grid
                    if !localImages.isEmpty {
                        LazyVGrid(columns: [
                            .init(.flexible()),
                            .init(.flexible()),
                            .init(.flexible())
                        ], spacing: 12) {
                            ForEach(Array(localImages.enumerated()), id: \.offset) { index, image in
                                photoThumbnail(image: image, index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if !localImages.isEmpty {
                        let goodPhotosCount = localImages.count - photoIssues.count
                        let hasEnoughGoodPhotos = goodPhotosCount >= 15
                        
                        VStack(spacing: 12) {
                            if isUploading {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(1.2)
                                    Text("Uploading photos...")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            } else {
                                if !hasEnoughGoodPhotos {
                                    // Warning message
                                    VStack(spacing: 12) {
                                        Text("Please remove problematic photos or add more good photos")
                                            .font(.subheadline)
                                            .foregroundColor(.yellow)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                        
                                        Button {
                                            // Go back to photo selection
                                            if let onAddMore = onAddMorePhotos {
                                                onAddMore()
                                            } else {
                                                // Fallback: navigate back programmatically
                                                // This will be handled by the navigation system
                                            }
                                        } label: {
                                            Text("Add More Photos")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(Color.pink.opacity(0.8))
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                    }
                                } else {
                                    Button {
                                        // Filter out problematic photos before uploading
                                        let goodPhotos = localImages.enumerated()
                                            .filter { index, _ in photoIssues[index] == nil }
                                            .map { $0.element }
                                        
                                        // Update localImages to only include good photos
                                        localImages = goodPhotos
                                        
                                        // Clear photoIssues since indices have changed
                                        photoIssues.removeAll()
                                        
                                        print("✅ Filtered photos: \(goodPhotos.count) good photos ready for upload")
                                        
                                        // Start upload and complete
                                        onComplete(selectedGender)
                                    } label: {
                                        Text("Continue")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [.pink, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .brandBackground()
        .navigationTitle("Review Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await checkPhotos()
        }
    }
    
    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        let hasIssue = photoIssues[index] != nil
        let issue = photoIssues[index]
        
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasIssue ? Color.yellow : Color.white.opacity(0.2), lineWidth: hasIssue ? 2 : 1)
                )
                .opacity(hasIssue ? 0.7 : 1.0)
            
            // Warning icon for problematic photos
            if hasIssue {
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    // Show issue description on long press
                    if let issue = issue {
                        Text(issue.description)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .lineLimit(2)
                            .frame(maxWidth: 100)
                    }
                }
                .padding(8)
            }
            
            // Remove button
            Button {
                // Remove photo and update issues dictionary
                localImages.remove(at: index)
                // Rebuild issues dictionary with correct indices
                var newIssues: [Int: PhotoIssue] = [:]
                for (oldIndex, issue) in photoIssues {
                    if oldIndex < index {
                        // Keep issues before removed index
                        newIssues[oldIndex] = issue
                    } else if oldIndex > index {
                        // Shift issues after removed index
                        newIssues[oldIndex - 1] = issue
                    }
                    // Skip the removed index
                }
                photoIssues = newIssues
                // Re-check photos after removal
                Task {
                    await checkPhotos()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .background(Color.white.clipShape(Circle()))
            }
            .offset(x: 6, y: -6)
        }
    }
    
    private func checkPhotos() async {
        isCheckingPhotos = true
        photoIssues.removeAll()
        
        await withTaskGroup(of: (Int, PhotoIssue?).self) { group in
            for (index, image) in localImages.enumerated() {
                group.addTask {
                    let issue = await analyzePhoto(image: image)
                    return (index, issue)
                }
            }
            
            for await (index, issue) in group {
                if let issue = issue {
                    photoIssues[index] = issue
                }
            }
        }
        
        isCheckingPhotos = false
    }
    
    private func analyzePhoto(image: UIImage) async -> PhotoIssue? {
        // Use actual pixel dimensions, not points
        guard let cgImage = image.cgImage else {
            print("❌ No CGImage available")
            return .poorQuality
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let minDimension = min(width, height)
        let maxDimension = max(width, height)
        
        print("📸 Analyzing photo: \(width)x\(height), orientation: \(image.imageOrientation.rawValue)")
        
        // Check if photo is too small
        if minDimension < 150 {
            return .tooSmall
        }
        
        // Check if photo is too large (might be compressed)
        if maxDimension > 8000 {
            return .tooLarge
        }
        
        // Very low resolution check
        if width < 200 || height < 200 {
            return .poorQuality
        }
        
        // FACE DETECTION - Use CIImage for better Vision framework compatibility
        let ciImage = CIImage(cgImage: cgImage)
        
        // Convert UIImage.Orientation to CGImagePropertyOrientation
        let cgOrientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: cgOrientation = .up
        case .down: cgOrientation = .down
        case .left: cgOrientation = .left
        case .right: cgOrientation = .right
        case .upMirrored: cgOrientation = .upMirrored
        case .downMirrored: cgOrientation = .downMirrored
        case .leftMirrored: cgOrientation = .leftMirrored
        case .rightMirrored: cgOrientation = .rightMirrored
        @unknown default: cgOrientation = .up
        }
        
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Try with CIImage first (most reliable)
        var observations: [VNFaceObservation] = []
        
        do {
            // Method 1: Use CIImage with proper orientation
            let ciHandler = VNImageRequestHandler(ciImage: ciImage, orientation: cgOrientation, options: [:])
            try ciHandler.perform([request])
            observations = request.results as? [VNFaceObservation] ?? []
            
            // Method 2: If no faces, try with .up orientation
            if observations.isEmpty {
                let upHandler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
                try upHandler.perform([request])
                observations = request.results as? [VNFaceObservation] ?? []
            }
            
            // Method 3: If still no faces, try with CGImage directly
            if observations.isEmpty {
                let cgHandler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
                try cgHandler.perform([request])
                observations = request.results as? [VNFaceObservation] ?? []
            }
            
            // Method 4: Try all orientations as last resort
            if observations.isEmpty {
                let allOrientations: [CGImagePropertyOrientation] = [.up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored]
                for orient in allOrientations {
                    let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orient, options: [:])
                    try handler.perform([request])
                    observations = request.results as? [VNFaceObservation] ?? []
                    if !observations.isEmpty {
                        print("✅ Face found with orientation: \(orient.rawValue)")
                        break
                    }
                }
            }
            
            // REJECT if no face detected
            if observations.isEmpty {
                print("❌ No face detected after trying all methods (size: \(width)x\(height))")
                return .noFace
            }
            
            print("✅ Found \(observations.count) face(s)")
            
            // REJECT if multiple faces - need single person photos
            if observations.count > 1 {
                print("⚠️ Multiple faces detected: \(observations.count)")
                return .multipleFaces
            }
            
            // Check face size - face must be reasonably prominent in the photo
            if let face = observations.first {
                let faceWidth = face.boundingBox.width * CGFloat(width)
                let faceHeight = face.boundingBox.height * CGFloat(height)
                let faceArea = faceWidth * faceHeight
                let imageArea = CGFloat(width * height)
                let faceRatio = faceArea / imageArea
                
                // Face should be at least 2% of the image (very relaxed to catch valid photos)
                if faceRatio < 0.02 {
                    print("⚠️ Face too small: \(String(format: "%.2f", faceRatio * 100))% of image")
                    return .poorQuality
                }
                
                // Also check that face is reasonably centered
                let faceCenterX = face.boundingBox.midX
                let faceCenterY = face.boundingBox.midY
                
                // Only reject if face is very small AND at the very edge
                if (faceCenterX < 0.02 || faceCenterX > 0.98 || faceCenterY < 0.02 || faceCenterY > 0.98) && faceRatio < 0.03 {
                    print("⚠️ Face too small and at edge: \(String(format: "%.2f", faceRatio * 100))%")
                    return .poorQuality
                }
                
                print("✅ Face OK: \(String(format: "%.2f", faceRatio * 100))% of image, center: (\(String(format: "%.1f", faceCenterX * 100))%, \(String(format: "%.1f", faceCenterY * 100))%)")
            }
            
            // Photo looks good - has single face, good size
            return nil
        } catch {
            print("❌ Face detection error: \(error.localizedDescription)")
            // Don't reject on error - let it through if other checks pass
            // This is a fallback to avoid false negatives
            return .noFace
        }
    }
}
