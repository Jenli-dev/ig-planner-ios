import SwiftUI

// MARK: - /ig/profile — краткая инфа по аккаунту
struct IGProfileSummary: Decodable {
    let id: String
    let username: String
    let name: String?
    let biography: String?
    let profile_picture_url: String?
    let media_count: Int?
    let followers_count: Int?
    let follows_count: Int?
}

// MARK: - Profile Header (UI секция)
struct ProfileHeaderSection: View {
    // Основные пропсы
    let avatarURL: String?
    let handle: String
    let posts: Int?
    let followers: Int?
    let followings: Int?
    let displayName: String?
    let bio: String?
    let lastUpdateDate: Date
    let isPro: Bool

    // Экшены
    var onRefresh: () -> Void
    var onGoPro: (() -> Void)? = nil
    var isLoading: Bool
    var onAccountSelect: (() -> Void)? = nil

    // Короткая форма чисел: 1200 -> 1.2K, 1_000_000 -> 1M
    private func short(_ n: Int?) -> String {
        guard let n else { return "—" }
        let v = Double(n)
        let units: [(Double, String)] = [
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K")
        ]
        for (thr, sfx) in units where v >= thr {
            let val = v / thr
            return val.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f%@", val, sfx)
            : String(format: "%.1f%@", val, sfx)
        }
        return "\(n)"
    }

    private var lastUpdateRelative: String {
        let rel = RelativeDateTimeFormatter()
        rel.locale = .current
        return rel.localizedString(for: lastUpdateDate, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Селектор аккаунта (кнопка сверху)
            Button(action: { onAccountSelect?() }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Text(displayName?.isEmpty == false ? (displayName ?? "Account") : "Test_User")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
            }
            
            // Аватар и статистика в одной строке
            HStack(alignment: .top, spacing: 16) {
                // Большой аватар слева
                Avatar(urlString: avatarURL, size: 80)
                
                // Статистика справа
                HStack(spacing: 24) {
                    Counter(title: "Posts", value: "\(posts ?? 0)")
                    Counter(title: "Followers", value: "\(followers ?? 0)")
                    Counter(title: "Followings", value: "\(followings ?? 0)")
                }
                
                Spacer()
            }
            
            // Username крупным шрифтом
            Text(handle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Last update + Refresh кнопка
            HStack {
                Text("Last update: \(lastUpdateFormatted)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button(action: onRefresh) {
                    Text("Refresh?")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                        .foregroundColor(.pink.opacity(0.9))
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1)
            }
        }
        .foregroundColor(.white)
    }
    
    private var lastUpdateFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(lastUpdateDate) {
            return "Today"
        } else if calendar.isDateInYesterday(lastUpdateDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: lastUpdateDate)
        }
    }
}

// MARK: - Avatar
private struct Avatar: View {
    let urlString: String?
    let size: CGFloat
    
    init(urlString: String?, size: CGFloat = 54) {
        self.urlString = urlString
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.18)).frame(width: size, height: size)

            if let s = urlString, let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(.white.opacity(0.85))
                            .frame(width: size, height: size)
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit()
                            .frame(width: size, height: size)
                            .foregroundColor(.white.opacity(0.9))
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(Circle())
            } else {
                // Placeholder icon
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Counter
private struct Counter: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Preview (опционально)
#if DEBUG
struct ProfileHeaderSection_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VStack {
                ProfileHeaderSection(
                    avatarURL: "https://i.pravatar.cc/150?img=3",
                    handle: "@your_handle",
                    posts: 128,
                    followers: 15420,
                    followings: 324,
                    displayName: "Instagram",
                    bio: "Your bio goes here. Multiline supported. 🌟",
                    lastUpdateDate: Date().addingTimeInterval(-7200),
                    isPro: false,
                    onRefresh: {},
                    onGoPro: {},
                    isLoading: false,
                    onAccountSelect: {}
                )
                .padding(20)
            }
        }
        .brandBackground() // ← единый фон
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
#endif
