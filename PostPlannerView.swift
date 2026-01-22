import SwiftUI
import PhotosUI   // на случай дальнейшего расширения

// MARK: - Screen
struct PostPlannerView: View {
    // State
    @State private var jobs: [PlannerJob] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showComposer = false
    
    // Gallery (локальные картинки из медиатеки)
    @State private var galleryImages: [UIImage] = []
    @State private var showImagePicker = false
    
    // Date formatting
    private var dfTime: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
    
    // Сетка 3 колонки под плитки
    private let grid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        ZStack {
            
            VStack(alignment: .leading, spacing: 16) {
                header
                
                // ===== Галерея-плитки =====
                if galleryImages.isEmpty {
                    galleryEmpty
                        .padding(.horizontal, 20)
                } else {
                    galleryGrid
                        .padding(.horizontal, 20)
                }
                
                // ===== Список задач =====
                ZStack {
                    if jobs.isEmpty {
                        emptyState
                    } else {
                        jobsList
                    }
                    
                    if isLoading && !jobs.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(radius: 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            fab
        }
        .brandBackground()
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Error",
               isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } })
        ) {
            Button("OK") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
        .sheet(isPresented: $showComposer) {
            PlannerComposer { newJob in
                jobs.insert(newJob, at: 0)
                showComposer = false
            } onCancel: {
                showComposer = false
            }
            .preferredColorScheme(.dark)
        }
        // Пикер изображений (ваш общий компонент)
        .sheet(isPresented: $showImagePicker) {
            LibraryPicker { image in
                guard let img = image else { return }
                // добавляем в начало, как “самые новые”
                galleryImages.insert(img, at: 0)
            }
        }
    }
    // MARK: - Pieces
    private var header: some View {
        Text("Post Planner")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }
    
    // Плашка “добавить фото”, если пусто
    private var galleryEmpty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your media")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                        Text("Add photos from Library")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // Сетка 3×N с “плитками” изображений и ячейкой “+”
    private var galleryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your media")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: grid, spacing: 12) {
                // Кнопка "+"
                Button {
                    showImagePicker = true
                } label: {
                    plusTile
                }
                .buttonStyle(.plain)
                
                // Сами превью
                ForEach(galleryImages.indices, id: \.self) { i in
                    tile(for: galleryImages[i])
                        .contextMenu {
                            Button(role: .destructive) {
                                galleryImages.remove(at: i)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
    
    // Отдельный вид плитки с изображением
    private func tile(for image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 110)
                .clipped()
        }
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    
    // Ячейка “+”
    private var plusTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
        }
    }
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
            Text("No scheduled posts yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text("Tap “+ Schedule” or use Publish flow to add a post.")
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
        }
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var jobsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(jobs) { job in
                    jobRow(job)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 90)
        }
    }

    private func jobRow(_ job: PlannerJob) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(job.captionOrPlaceholder)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(2)

                Text(dfTime.string(from: job.publishAtUTC ?? Date()))
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var fab: some View {
        VStack {
            Spacer()
            Button {
                showComposer = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 64, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.blue))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .shadow(radius: 8, y: 4)
            }
            .accessibilityLabel("Schedule post")
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Networking
    private func reload() async {
        await MainActor.run { isLoading = true; errorText = nil }
        do {
            let url = API.url("/ig/schedule")
            let resp: ScheduleListResp = try await API.getJSON(url)
            let mapped = resp.jobs
                .map { (id, raw) in PlannerJob.fromRaw(id: id, raw: raw) }
                .sorted { a, b in
                    func rank(_ s: String) -> Int {
                        switch s.lowercased() {
                        case "scheduled": return 0
                        case "done":      return 1
                        case "error":     return 2
                        case "canceled":  return 3
                        default:          return 9
                        }
                    }
                    if rank(a.status) != rank(b.status) { return rank(a.status) < rank(b.status) }
                    let da = a.publishAtUTC ?? .distantFuture
                    let db = b.publishAtUTC ?? .distantFuture
                    return da < db
                }

            await MainActor.run { self.jobs = mapped }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }
}

