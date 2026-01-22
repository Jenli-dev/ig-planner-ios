import SwiftUI
import UIKit

// MARK: - Enums

enum AvatarTab: String, CaseIterable {
    case styles = "Styles"
    case generate = "Generate"
    case history = "History"
}

enum AvatarGender: String, CaseIterable {
    case woman = "Woman"
    case man = "Man"
}

enum AIModel: String, CaseIterable {
    case fluxT2I = "Flux Text to Image"
    case fluxI2I = "Flux Image to Image"
    
    var displayName: String {
        switch self {
        case .fluxT2I: return "Flux Text to Image"
        case .fluxI2I: return "Flux Image to Image"
        }
    }
    
    var description: String {
        switch self {
        case .fluxT2I: return "Generate an image with you based on text"
        case .fluxI2I: return "Generate an image of you from another image"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AvatarGenerationVM: ObservableObject {
    @Published var imageURLs: [String] = []
    @Published var prompt: String = "avatar style, clean skin, studio light"
    @Published var strength: Double = 0.55
    @Published var aspectRatio: String = "1:1"
    @Published var variantsPerImage: Int = 1
    @Published var selectedGender: AvatarGender? = nil
    @Published var selectedAIModel: AIModel = .fluxT2I
    
    @Published var isLoading = false
    @Published var jobID: String?
    @Published var status: String?
    @Published var stage: String?
    @Published var result: AIJobResult?
    @Published var errorText: String?
    
    @Published var history: [AIJobResult] = []
    
    init() {
        loadHistory()
    }
    
    func generate(hasSubscription: Bool) async {
        guard imageURLs.count >= 15 && imageURLs.count <= 50 else {
            errorText = "Please add 15-50 images"
            return
        }
        
        guard hasSubscription else {
            // This should be handled by the view showing the paywall
            errorText = "Subscription required. Please subscribe to generate avatars."
            return
        }
        
        isLoading = true
        errorText = nil
        jobID = nil
        result = nil
        defer { isLoading = false }
        
        // Add gender to prompt if selected
        var finalPrompt = prompt
        if let gender = selectedGender {
            finalPrompt = "\(prompt), \(gender.rawValue.lowercased()) portrait"
        }
        
        do {
            let response = try await AIGenerationAPI.generateAvatarBatch(
                imageURLs: imageURLs,
                prompt: finalPrompt,
                strength: strength,
                aspectRatio: aspectRatio,
                variantsPerImage: variantsPerImage
            )
            
            jobID = response.job_id
            status = "PENDING"
            stage = "queued"
            
            // Start polling
            await pollStatus()
        } catch {
            // Check if error is about subscription/credits
            if let apiError = error as? APIError,
               case .badStatus(let code, _) = apiError,
               code == 402 {
                errorText = "Subscription required or insufficient credits. Please check your subscription and credits."
            } else {
                errorText = error.localizedDescription
            }
        }
    }
    
    private func pollStatus() async {
        guard let jobID = jobID else { return }
        
        while true {
            do {
                let status = try await AIGenerationAPI.getJobStatus(jobID: jobID)
                self.status = status.status
                self.stage = status.stage
                
                if let error = status.error {
                    // Improve error messages for better user experience
                    if error.contains("All batch items failed") || error.lowercased().contains("failed") {
                        errorText = "Generation failed. Some photos may not be suitable. Please try uploading different photos with clear face, good lighting, and single person per photo."
                    } else {
                        errorText = error
                    }
                    break
                }
                
                if status.status == "DONE" {
                    if let result = status.result {
                        // Check if result has any generated images
                        if let summary = result.summary, summary.total_generated == 0 {
                            errorText = "Generation completed but no images were created. Please try uploading different photos with clear face, good lighting, and single person per photo."
                        } else {
                            self.result = result
                            addToHistory(result)
                        }
                    }
                    break
                }
                
                if status.status == "ERROR" {
                    let errorMsg = status.error ?? "Generation failed"
                    if errorMsg.contains("All batch items failed") || errorMsg.lowercased().contains("failed") {
                        errorText = "Generation failed. Some photos may not be suitable. Please try uploading different photos with clear face, good lighting, and single person per photo."
                    } else {
                        errorText = errorMsg
                    }
                    break
                }
                
                // Poll every 2 seconds
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                errorText = error.localizedDescription
                break
            }
        }
    }
    
    func reset() {
        imageURLs = []
        prompt = "avatar style, clean skin, studio light"
        strength = 0.55
        aspectRatio = "1:1"
        variantsPerImage = 1
        selectedGender = nil
        jobID = nil
        status = nil
        stage = nil
        result = nil
        errorText = nil
    }
    
    // MARK: - History
    
    private func addToHistory(_ result: AIJobResult) {
        history.insert(result, at: 0)
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "avatar_generation_history")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "avatar_generation_history"),
           let decoded = try? JSONDecoder().decode([AIJobResult].self, from: data) {
            history = decoded
        }
    }
}

// MARK: - Screen

struct AvatarGenerationScreen: View {
    @StateObject private var vm = AvatarGenerationVM()
    @EnvironmentObject var purchases: PurchaseManager
    
    @State private var selectedTab: AvatarTab = .styles
    @State private var showFormatModal = false
    @State private var showAIModelModal = false
    @State private var showPhotoUploadFlow = false
    @State private var showStylesDetail: CategoryIdentifier? = nil
    @State private var showAIAvatarPaywall = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                header
                
                // Tab Picker
                tabPicker
                
                // Content based on selected tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .styles:
                            stylesTabView
                        case .generate:
                            generateTabView
                        case .history:
                            historyTabView
                        }
                        
                        Spacer(minLength: 90)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .brandBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("AI Avatar")
        .sheet(isPresented: $showFormatModal) {
            AvatarFormatModal(selectedFormat: $vm.aspectRatio)
        }
        .sheet(isPresented: $showAIModelModal) {
            AIModelModal(selectedModel: $vm.selectedAIModel)
        }
        .sheet(isPresented: $showPhotoUploadFlow) {
            PhotoUploadFlowView(
                selectedImages: $vm.imageURLs,
                selectedGender: $vm.selectedGender
            ) { gender in
                // Update gender
                vm.selectedGender = gender
                
                // Verify that images were actually uploaded
                print("📸 Photo upload complete. imageURLs count: \(vm.imageURLs.count)")
                
                if vm.imageURLs.count < 15 {
                    // Not enough photos - don't close sheet, show error
                    print("⚠️ Not enough photos uploaded: \(vm.imageURLs.count), need at least 15")
                    // The sheet will stay open, user can retry
                    return
                }
                
                // Close the sheet
                showPhotoUploadFlow = false
                
                // Switch to Generate tab after photo upload is complete
                // Use a small delay to ensure data is set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selectedTab = .generate
                    print("✅ Switched to Generate tab with \(vm.imageURLs.count) photos")
                }
            }
        }
        .sheet(item: $showStylesDetail) { category in
            StylesDetailScreen(category: category) {
                // Switch to Generate tab when Generate button is tapped
                selectedTab = .generate
            }
        }
        .sheet(isPresented: $showAIAvatarPaywall) {
            AIAvatarPaywallView(
                onClose: {
                    showAIAvatarPaywall = false
                },
                onSubscribed: {
                    showAIAvatarPaywall = false
                    // Retry generation after subscription
                    Task {
                        await vm.generate(hasSubscription: true)
                    }
                }
            )
            .environmentObject(purchases)
        }
    }
    
    // MARK: - Header
    
    @State private var creditsBalance: Int? = nil
    @State private var isLoadingCredits = false
    
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("AI Avatar")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if purchases.hasAIAvatarSubscription {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    if isLoadingCredits {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else if let balance = creditsBalance {
                        Text("\(balance)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text("0")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            Spacer()
            
            Button {
                // This button appears to be a placeholder/decorative element
                // If needed, can be used for account selection in the future
            } label: {
                HStack(spacing: 4) {
                    Text("Avatar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .task {
            await loadCreditsBalance()
        }
        .onChange(of: purchases.hasAIAvatarSubscription) { _, hasSubscription in
            if hasSubscription {
                Task {
                    await loadCreditsBalance()
                }
            } else {
                creditsBalance = nil
            }
        }
    }
    
    private func loadCreditsBalance() async {
        guard purchases.hasAIAvatarSubscription else {
            creditsBalance = nil
            return
        }
        
        isLoadingCredits = true
        defer { isLoadingCredits = false }
        
        do {
            let balance = try await AIAvatarSubscriptionAPI.getCreditsBalance(userID: nil)
            await MainActor.run {
                creditsBalance = balance.credits_remaining
            }
        } catch {
            print("⚠️ Failed to load credits balance: \(error)")
        }
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(AvatarTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Styles Tab
    
    private var stylesTabView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Gender selector
            genderSelector
            
            // Style categories
            styleCategories
        }
    }
    
    private var genderSelector: some View {
        HStack(spacing: 12) {
            ForEach(AvatarGender.allCases, id: \.self) { gender in
                Button {
                    vm.selectedGender = vm.selectedGender == gender ? nil : gender
                } label: {
                    Text(gender.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(vm.selectedGender == gender ? .pink : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(vm.selectedGender == gender ? Color.white : Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var styleCategories: some View {
        VStack(alignment: .leading, spacing: 20) {
            styleCategoryRow(
                title: "TOP-25",
                emoji: "🏆",
                category: "top25",
                examples: top25Examples
            )
            
            styleCategoryRow(
                title: "Studio Shot",
                emoji: "📸",
                category: "studio",
                examples: studioShotExamples
            )
            
            styleCategoryRow(
                title: "Old Money",
                emoji: "💰",
                category: "oldmoney",
                examples: oldMoneyExamples
            )
            
            styleCategoryRow(
                title: "Modern",
                emoji: "✨",
                category: "modern",
                examples: modernExamples
            )
        }
    }
    
    private func styleCategoryRow(title: String, emoji: String, category: String, examples: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showStylesDetail = CategoryIdentifier(category)
                } label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(examples.prefix(6), id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 120, height: 120)
                                        ProgressView().tint(.white)
                                    }
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 120, height: 120)
                                        Image(systemName: "photo")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Generate Tab
    
    private var generateTabView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI Model selector
            selectorButton(
                icon: "camera.rotate",
                title: "AI Model: \(vm.selectedAIModel.displayName)"
            ) {
                showAIModelModal = true
            }
            
            // Avatar format selector
            selectorButton(
                icon: "checkmark.square",
                title: "Avatar format: \(vm.aspectRatio)"
            ) {
                showFormatModal = true
            }
            
            // Create avatar button
            createAvatarButton
            
            Spacer()
            
            // Generate button
            generateButton
            
            // Status & Results
            if vm.isLoading || vm.status != nil {
                statusSection
            }
            
            if let result = vm.result {
                resultsSection(result: result)
            }
            
            if let error = vm.errorText {
                errorSection(error: error)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private func selectorButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var createAvatarButton: some View {
        Button {
            showPhotoUploadFlow = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Create avatar")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white)
            .padding(16)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var generateButton: some View {
        Button {
            // Check subscription before generating
            if purchases.hasAIAvatarSubscription {
                Task {
                    await vm.generate(hasSubscription: true)
                }
            } else {
                // Show paywall
                showAIAvatarPaywall = true
            }
        } label: {
            Text("Generate")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(vm.isLoading || vm.imageURLs.count < 15)
        .opacity(vm.isLoading || vm.imageURLs.count < 15 ? 0.6 : 1.0)
        .padding(.top, 8)
    }
    
    // MARK: - History Tab
    
    private var historyTabView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    // Sorting
                } label: {
                    HStack(spacing: 4) {
                        Text("Sorting")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        Text("by date (descending)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if vm.history.isEmpty {
                emptyHistoryView
            } else {
                historyGridView
            }
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))
            Text("It's empty for now")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            Text("In the future, avatars generated by you will be here!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }
    
    private var historyGridView: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(Array(vm.history.enumerated()), id: \.offset) { index, result in
                if let items = result.items, !items.isEmpty, let firstImage = items.first?.generated_images.first {
                    AsyncImage(url: URL(string: firstImage)) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
                                ProgressView().tint(.white)
                            }
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
                                Image(systemName: "exclamationmark.triangle")
                            }
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Status & Results
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let stage = vm.stage {
                HStack {
                    ProgressView().tint(.white)
                    Text(stageText(stage))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func resultsSection(result: AIJobResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = result.summary {
                Text("Generated: \(summary.total_generated) avatars from \(summary.count_sources) photos")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if let items = result.items {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if !item.generated_images.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                AsyncImage(url: URL(string: item.generated_images[0])) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
                                            ProgressView().tint(.white)
                                        }
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
                                            Image(systemName: "exclamationmark.triangle")
                                        }
                                    @unknown default: EmptyView()
                                    }
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("\(item.generated_images.count) variant\(item.generated_images.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func errorSection(error: String) -> some View {
        Text(error)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
    
    private func stageText(_ stage: String) -> String {
        switch stage {
        case "queued": return "Queued..."
        case "running": return "Generating avatars..."
        case "uploading": return "Uploading results..."
        case "done": return "Complete!"
        case "error": return "Error occurred"
        default: return "Processing..."
        }
    }
    
    // MARK: - Example Images
    
    private var top25Examples: [String] {
        [
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=400&h=400&fit=crop&crop=faces"
        ]
    }
    
    private var studioShotExamples: [String] {
        [
            "https://images.unsplash.com/photo-1509475826633-fed577a2c71b?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=400&h=400&fit=crop&crop=faces"
        ]
    }
    
    private var oldMoneyExamples: [String] {
        [
            "https://images.unsplash.com/photo-1521119989659-a83eee488004?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces"
        ]
    }
    
    private var modernExamples: [String] {
        [
            "https://images.unsplash.com/photo-1506863530036-1efeddceb993?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces"
        ]
    }
}

// MARK: - Extensions

// MARK: - Navigation Helper

struct CategoryIdentifier: Identifiable {
    let id: String
    init(_ value: String) {
        self.id = value
    }
}

// MARK: - Supporting Views (will be added in next part)

struct AvatarFormatModal: View {
    @Binding var selectedFormat: String
    @Environment(\.dismiss) private var dismiss
    
    let formats = [
        ("1:1", "Square"),
        ("3:4", "Standard"),
        ("4:3", "Classic"),
        ("9:16", "Social Story"),
        ("16:9", "Widescreen"),
        ("5:8", "Art Format")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Brand background
                AppGradient.brand
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(formats, id: \.0) { format, name in
                            formatButton(format: format, name: name)
                        }
                    }
                    .padding(20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Avatar format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func formatButton(format: String, name: String) -> some View {
        let isSelected = selectedFormat == format
        
        return Button {
            selectedFormat = format
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.portrait")
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .gray)
                Text(format)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white)
                Text(name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(formatBackground(isSelected: isSelected))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            AnyShapeStyle(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            AnyShapeStyle(Color.white.opacity(0.12))
        }
    }
}

struct AIModelModal: View {
    @Binding var selectedModel: AIModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Brand background
                AppGradient.brand
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ForEach(AIModel.allCases, id: \.self) { model in
                        modelButton(model: model)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func modelButton(model: AIModel) -> some View {
        let isSelected = selectedModel == model
        
        return Button {
            selectedModel = model
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white)
                Text(model.description)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(modelBackground(isSelected: isSelected))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func modelBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            AnyShapeStyle(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing))
        } else {
            AnyShapeStyle(Color.white.opacity(0.12))
        }
    }
}

// MARK: - Styles Detail Screen

struct StylesDetailScreen: View {
    let category: CategoryIdentifier
    let onGenerate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var categoryTitle: String {
        switch category.id {
        case "top25": return "TOP-25"
        case "studio": return "Studio Shot"
        case "oldmoney": return "Old Money"
        case "modern": return "Modern"
        default: return "Styles"
        }
    }
    
    var categoryExamples: [String] {
        switch category.id {
        case "top25":
            return [
                "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=faces"
            ]
        case "studio":
            return [
                "https://images.unsplash.com/photo-1509475826633-fed577a2c71b?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1509475826633-fed577a2c71b?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces"
            ]
        case "oldmoney":
            return [
                "https://images.unsplash.com/photo-1521119989659-a83eee488004?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1521119989659-a83eee488004?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400&h=400&fit=crop&crop=faces"
            ]
        case "modern":
            return [
                "https://images.unsplash.com/photo-1506863530036-1efeddceb993?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506863530036-1efeddceb993?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&crop=faces",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=faces"
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Grid of style examples (3x3)
                    LazyVGrid(columns: [
                        .init(.flexible()),
                        .init(.flexible()),
                        .init(.flexible())
                    ], spacing: 12) {
                        ForEach(categoryExamples, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.12))
                                                .aspectRatio(1, contentMode: .fit)
                                            ProgressView().tint(.white)
                                        }
                                    case .success(let img):
                                        img
                                            .resizable()
                                            .scaledToFill()
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    case .failure:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.12))
                                                .aspectRatio(1, contentMode: .fit)
                                            Image(systemName: "photo")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Generate button
                    Button {
                        dismiss()
                        onGenerate()
                    } label: {
                        Text("Generate")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [.pink, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .brandBackground()
        .navigationTitle(categoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

