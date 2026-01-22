import SwiftUI

// MARK: - Универсальный декодер числа, которое может прийти строкой
enum JSONNumberOrString: Decodable {
    case int(Int)
    case string(String)

    var intValue: Int? {
        switch self {
        case .int(let v): return v
        case .string(let s): return Int(s)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Int.self) {
            self = .int(v)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.typeMismatch(
                JSONNumberOrString.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or String"
                )
            )
        }
    }
}

// MARK: - /ig/insights/account  (Facebook Graph формат)
struct FBAccountInsightsResponse: Decodable {
    let data: [FBMetricBucket]
}

struct FBMetricBucket: Decodable {
    let name: String                 // "impressions", "reach", "profile_views"
    let period: String?              // "day"
    let values: [FBMetricPoint]      // [{ value, end_time }]
}

struct FBMetricPoint: Decodable {
    let value: JSONNumberOrString
    let end_time: String?
}

// MARK: - /ig/media
struct IGMediaResponse: Decodable {
    let data: [IGMediaItem]
    // paging пока не нужен
}

struct IGMediaItem: Decodable, Identifiable {
    let id: String
    let media_type: String?
    let media_url: String?
    let thumbnail_url: String?
    let timestamp: String?
    let product_type: String?
}

// MARK: - /ig/insights/media
struct MediaInsightsResponse: Decodable {
    let data: [MediaMetric]
}

struct MediaMetric: Decodable {
    let name: String                 // "views", "likes", ...
    let values: [MediaMetricValue]
}

struct MediaMetricValue: Decodable {
    let value: JSONNumberOrString
}

// MARK: - Локальный снапшот для баннера дельт
struct AccountDeltaSnapshot: Codable {
    let date: Date
    let impressions: Int
    let reach: Int
    let profileViews: Int
}

let kLastInsightsKey = "analytics.last.account.insights"
// MARK: - Analytics (grid)
struct AnalyticsView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @State private var showPaywall = false
    @State private var showAvatarGeneration = false
    
    // Header/profile
    @State private var igUsername: String? = nil
    @State private var profile: IGProfileSummary? = nil
    
    // Loading / errors
    @State private var isLoading = false
    @State private var errorText: String?
    
    // Account insights
    @State private var lastUpdate: Date?
    @State private var account: AccountDeltaSnapshot?          // текущие агрегаты
    @State private var previousAccount: AccountDeltaSnapshot?  // сохранённые агрегаты для дельт
    
    // Media
    @State private var topPosts: [IGMediaItem] = []
    @State private var selectedMedia: IGMediaItem? = nil       // откроем sheet по тапу
    
    // Удобный форматтер для "Last update"
    private var lastUpdateString: String {
        guard let d = lastUpdate else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: d)
    }
    
    // список плиток (как было)
    private let features: [FeatureItem] = [
        .init(icon: "person.crop.circle.badge.xmark", title: "Not Follow Me Back",   subtitle: "Who is not interested in you", value: 16, pro: true),
        .init(icon: "questionmark.circle",            title: "View but not follow",   subtitle: "Who is interested in me",      value: 12, pro: true),
        .init(icon: "person.badge.plus",              title: "New Followers",         subtitle: "Recently appeared",            value: 23, delta: "+23", pro: true),
        .init(icon: "person.badge.minus",             title: "Lost Followers",        subtitle: "Recently appeared",            value: 17, delta: "+17", pro: true),
        .init(icon: "person.crop.circle.badge.exclam",title: "I Don't Follow Back",   subtitle: "Who I am not interested in",   value: 20, pro: true),
        .init(icon: "person.2",                       title: "Manual Followers",      subtitle: "Mutual subscriptions",         value: 25, pro: false),
        .init(icon: "questionmark.circle.fill",                     title: "Ghost Followers",       subtitle: "Who is Inactive",              value: 3,  pro: true),
        .init(icon: "person.3.sequence",              title: "Active Followers",      subtitle: "Who interacts with you",       value: 28, pro: true),
        .init(icon: "checkmark.seal",                 title: "Verified Followers",    subtitle: "With a blue badge",            value: 4,  pro: false),
        .init(icon: "lock.shield",                    title: "Private Followers",     subtitle: "Who have private accounts",    value: 10, pro: false)
    ]
    
    // MARK: - Local storage helpers (previousAccount ↔︎ UserDefaults)
    private func loadPreviousSnapshot() {
        if let data = UserDefaults.standard.data(forKey: kLastInsightsKey) {
            previousAccount = try? JSONDecoder().decode(AccountDeltaSnapshot.self, from: data)
        } else {
            previousAccount = nil
        }
    }
    
    private func saveCurrentSnapshot() {
        guard let current = account else { return }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: kLastInsightsKey)
        }
    }
    
    /// Перед фетчем новых инсайтов — сдвигаем current → previous
    private func rollCurrentToPreviousIfNeeded() {
        if previousAccount == nil { loadPreviousSnapshot() }
        if let curr = account { previousAccount = curr }
    }
    // MARK: - Networking
    private func reloadAll() async {
        await MainActor.run { isLoading = true; errorText = nil }
        rollCurrentToPreviousIfNeeded()
        do {
            try await fetchProfileSummary()     // <-- грузим профиль
            try await fetchAccountInsights()
            try await fetchTopPosts()
            await MainActor.run {
                lastUpdate = Date()
                saveCurrentSnapshot()
            }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }

        #if DEBUG
        if profile == nil {
            await MainActor.run {
                self.profile = IGProfileSummary(
                    id: "demo",
                    username: "sunroast_vibes_2901",
                    name: "Test_User",
                    biography: nil,
                    profile_picture_url: nil,
                    media_count: 10,
                    followers_count: 250,
                    follows_count: 150
                )
                // Set last update to today
                self.lastUpdate = Date()
            }
        }
        #endif

        await MainActor.run { isLoading = false }
    }

    // /me/instagram — покажем username в шапке
    private func fetchMeInstagram() async throws {
        struct MeResp: Decodable {
            struct IGBiz: Decodable { let id: String; let username: String? }
            let instagram_business_account: IGBiz?
        }
        let url = API.url("/me/instagram")
        let resp: MeResp = try await API.getJSON(url)
        await MainActor.run {
            igUsername = resp.instagram_business_account?.username
        }
    }

    // /ig/insights/account — тянем 3 метрики и собираем срез
    private func fetchAccountInsights() async throws {
        let url = API.url("/ig/insights/account",
                          [URLQueryItem(name: "metrics", value: "impressions,reach,profile_views"),
                           URLQueryItem(name: "period", value: "day")])
        let resp: FBAccountInsightsResponse = try await API.getJSON(url)

        func pick(_ name: String) -> Int {
            let bucket = resp.data.first { $0.name == name }
            let last = bucket?.values.last?.value.intValue ?? 0
            return last
        }

        let snap = AccountDeltaSnapshot(
            date: Date(),
            impressions: pick("impressions"),
            reach: pick("reach"),
            profileViews: pick("profile_views")
        )
        await MainActor.run {
            account = snap
        }
    }

    // /ig/media — для секции Top posts
    private func fetchTopPosts() async throws {
        let url = API.url("/ig/media", [URLQueryItem(name: "limit", value: "12")])
        let resp: IGMediaResponse = try await API.getJSON(url)

        await MainActor.run {
            topPosts = resp.data
        }
    }

    // По клику по карточке — добираем insights конкретного поста
    private func fetchInsights(for mediaID: String) async throws -> MediaInsightsResponse {
        let url = API.url("/ig/insights/media",
                          [URLQueryItem(name: "media_id", value: mediaID)])
        return try await API.getJSON(url)
    }

    // /ig/profile — базовые данные профиля (устойчивый декодинг + лог на ошибке)
    private func fetchProfileSummary() async throws {
        let url = API.url("/ig/profile")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "AnalyticsView.fetchProfileSummary",
                          code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: text])
        }

        // декодер понимает snake_case -> camelCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct ProfileDTO: Decodable {
            let id: String
            let username: String
            let name: String?
            let biography: String?
            let profilePictureUrl: String?
            let mediaCount: Int?
            let followersCount: Int?
            let followsCount: Int?
        }

        do {
            let dto = try decoder.decode(ProfileDTO.self, from: data)
            let mapped = IGProfileSummary(
                id: dto.id,
                username: dto.username,
                name: dto.name,
                biography: dto.biography,
                profile_picture_url: dto.profilePictureUrl,
                media_count: dto.mediaCount,
                followers_count: dto.followersCount,
                follows_count: dto.followsCount
            )
            await MainActor.run { self.profile = mapped }
        } catch {
            #if DEBUG
            if let s = String(data: data, encoding: .utf8) {
                print("⚠️ /ig/profile raw JSON:\n\(s)")
            }
            print("⚠️ decode error:", error)
            #endif

            // Пробуем достать хотя бы username
            await loadUsernameFallback()
            if profile == nil {
                // фолбэк тоже не помог — пробрасываем ошибку
                throw error
            }
        }
    }
        
    private func loadUsernameFallback() async {
        do {
            struct MeResp: Decodable {
                struct IGBiz: Decodable { let id: String; let username: String? }
                let instagram_business_account: IGBiz?
            }
            let url = API.url("/me/instagram")
            let me: MeResp = try await API.getJSON(url)
            if let uname = me.instagram_business_account?.username {
                await MainActor.run {
                    self.profile = IGProfileSummary(
                        id: "local",
                        username: uname,
                        name: nil,
                        biography: nil,
                        profile_picture_url: nil,
                        media_count: nil,
                        followers_count: nil,
                        follows_count: nil
                    )
                }
            }
        } catch {
            #if DEBUG
            print("Fallback username failed:", error)
            #endif
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ===== ШАПКА ПРОФИЛЯ =====
                    if let p = profile {
                        ProfileHeaderSection(
                            avatarURL: p.profile_picture_url,
                            handle: p.username,
                            posts: p.media_count,
                            followers: p.followers_count,
                            followings: p.follows_count,
                            displayName: p.name ?? "Test_User",
                            bio: p.biography,
                            lastUpdateDate: lastUpdate ?? Date(),
                            isPro: purchases.isPro,
                            onRefresh: { Task { await reloadAll() } },
                            isLoading: isLoading,
                            onAccountSelect: {
                                // TODO: Показать меню выбора аккаунта
                                print("Account selection tapped")
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    } else {
                        // компактный плейсхолдер, пока профиль грузится
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 120, height: 14)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 180, height: 12)
                                }

                                Spacer()
                                if isLoading { ProgressView().tint(.white) }
                            }

                            HStack {
                                Label("Last update \(lastUpdateString)", systemImage: "clock")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                                Button {
                                    Task { await reloadAll() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Refresh")
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15), in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    // Delta banner
                    if let cur = account, let prev = previousAccount {
                        DeltaBanner(current: cur, previous: prev)
                            .padding(.horizontal, 20)
                    }

                    // Top posts
                    if !topPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Top posts")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(topPosts) { item in
                                        MediaThumbCard(item: item)
                                            .onTapGesture {
                                                guard !isLoading else { return }
                                                selectedMedia = item
                                            }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }

                    // AI Avatar Card
                    AIAvatarPromoCard()
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            showAvatarGeneration = true
                        }

                    // Grid 2xN
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                        spacing: 16
                    ) {
                        ForEach(features) { item in
                            FeatureCard(
                                item: item,
                                isLocked: item.pro && !purchases.isPro
                            )
                            .onTapGesture {
                                if item.pro && !purchases.isPro {
                                    showPaywall = true
                                } else {
                                    // TODO: навигация в детали метрики
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .refreshable {            // pull-to-refresh
                await reloadAll()
            }
            .task {                   // автозагрузка при первом появлении
                await reloadAll()
            }
            .brandBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if purchases.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.18), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    } else {
                        Button { showPaywall = true } label: {
                            Text("Go Pro")
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15), in: Capsule())
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                ),
                actions: { Button("OK") { errorText = nil } },
                message: { Text(errorText ?? "") }
            )
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallContainer {
                    showPaywall = false      // onClose
                } onSubscribed: {
                    showPaywall = false      // авто-закрытие после покупки
                }
            }
            .sheet(item: $selectedMedia) { m in
                MediaInsightsSheet(media: m)
            }
            .fullScreenCover(isPresented: $showAvatarGeneration) {
                NavigationStack {
                    AvatarGenerationScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showAvatarGeneration = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(8)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }
                            }
                        }
                }
            }
        } // NavigationStack
    } // body
    // MARK: - Models
    private struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let value: Int
        var delta: String? = nil       // например “+23”
        var pro: Bool = true           // признак, что метрика требует Pro
    }

    // MARK: - Card
    private struct FeatureCard: View {
        let item: FeatureItem
        let isLocked: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.white.opacity(0.15), in: Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    Spacer(minLength: 0)
                }

                Text(item.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.value)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    if let delta = item.delta {
                        Text(delta)
                            .font(.footnote.weight(.semibold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.15), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    // MARK: - Delta banner
    private struct DeltaBanner: View {
        let current: AccountDeltaSnapshot
        let previous: AccountDeltaSnapshot

        private func pill(_ title: String, _ diff: Int) -> some View {
            let sign = diff > 0 ? "+"
                : (diff < 0 ? "−" : "")
            let color: Color = diff > 0 ? .green : (diff < 0 ? .red : .white.opacity(0.9))

            return HStack(spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                Text("\(sign)\(abs(diff))")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(color)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
        }

        var body: some View {
            let dImpr  = current.impressions  - previous.impressions
            let dReach = current.reach        - previous.reach
            let dPV    = current.profileViews - previous.profileViews

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    pill("Impressions", dImpr)
                    pill("Reach", dReach)
                    pill("Profile views", dPV)
                }
                .padding(12)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .padding(.vertical, 2)
            }
        }
    }
    // MARK: - Top posts: media thumb
    private struct MediaThumbCard: View {
        let item: IGMediaItem

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 120, height: 160)

                    if let urlStr = item.thumbnail_url ?? item.media_url,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().tint(.white)
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 120, height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                }

                Text(item.media_type ?? "")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    // MARK: - AI Avatar Promo Card
    private struct AIAvatarPromoCard: View {
        // Example avatar images for preview
        private let exampleAvatars = [
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=200&h=200&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=faces"
        ]
        
        var body: some View {
            HStack(spacing: 16) {
                // Three overlapping avatar images with stars
                ZStack(alignment: .leading) {
                    ForEach(Array(exampleAvatars.enumerated()), id: \.offset) { index, urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 56, height: 56)
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                        )
                                case .failure:
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 56, height: 56)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .offset(x: CGFloat(index * 28))
                            .zIndex(Double(exampleAvatars.count - index))
                        }
                    }
                    
                    // Sparkle icons around avatars
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: 70, y: -10)
                        .zIndex(10)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.9))
                        .offset(x: 75, y: 8)
                        .zIndex(10)
                }
                .frame(width: 120, height: 56)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart profile pic")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Generate your AI-powered look")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
        }
    }

    // MARK: - Preview
    struct AnalyticsView_Previews: PreviewProvider {
        static var previews: some View {
            AnalyticsView()
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Media insights sheet (минимум)
    private struct MediaInsightsSheet: View {
        @Environment(\.dismiss) private var dismiss
        let media: IGMediaItem
        @State private var metrics: [MediaMetric] = []
        @State private var isLoading = true
        @State private var errorText: String?

        var body: some View {
            NavigationStack {
                List {
                    if let urlStr = media.thumbnail_url ?? media.media_url,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit()
                            case .empty: ProgressView()
                            case .failure: Image(systemName: "photo")
                            @unknown default: EmptyView()
                            }
                        }
                        .listRowInsets(EdgeInsets())
                    }

                    Section("Metrics") {
                        if isLoading {
                            HStack { ProgressView(); Text("Loading…") }
                        } else if let err = errorText {
                            Text(err).foregroundColor(.red)
                        } else if metrics.isEmpty {
                            Text("No metrics")
                        } else {
                            ForEach(metrics, id: \.name) { m in
                                let v = m.values.first?.value.intValue ?? 0
                                HStack { Text(m.name.capitalized); Spacer(); Text("\(v)") }
                            }
                        }
                    }
                }
                .navigationTitle("Post insights")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
                .task { await loadInsights() }
            }
        }

        private func loadInsights() async {
            isLoading = true; errorText = nil
            do {
                let url = API.url("/ig/insights/media", [
                    .init(name: "media_id", value: media.id)
                ])
                let resp: MediaInsightsResponse = try await API.getJSON(url)
                await MainActor.run {
                    self.metrics = resp.data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
