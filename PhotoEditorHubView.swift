import SwiftUI

private enum EditorRoute: Hashable {
    case filters, covers, watermark, resize, avatars
}

struct PhotoEditorHubView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showPaywall = false
    @State private var path = NavigationPath()

    private var isPro: Bool { purchases.isPro }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Заголовок в том же стиле
                        Text("Photo Editor")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // Подзаголовки
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create better visuals")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)

                            Text("Quick tools for filters, covers, watermark & resize.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 20)

                        // Плитки-фич
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {

                            featureCard(
                                title: "Filters",
                                subtitle: "Photo & Video",
                                systemImage: "wand.and.stars.inverse"
                            ) { navigate(.filters) }
                            .padding(.horizontal, 20)

                            featureCard(
                                title: "Covers",
                                subtitle: "Reels & Posts",
                                systemImage: "rectangle.on.rectangle.angled"
                            ) { navigate(.covers) }
                            .padding(.horizontal, 20)

                            featureCard(
                                title: "Watermark",
                                subtitle: "Logo overlay",
                                systemImage: "drop.degreesign"
                            ) { navigate(.watermark) }
                            .padding(.horizontal, 20)

                            featureCard(
                                title: "Resize",
                                subtitle: "Crop & fit",
                                systemImage: "arrow.up.left.and.down.right.magnifyingglass"
                            ) { navigate(.resize) }
                            .padding(.horizontal, 20)
                            
                            featureCard(
                                title: "Avatars",
                                subtitle: "AI Generation",
                                systemImage: "person.crop.circle.badge.plus"
                            ) { navigate(.avatars) }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 4)

                        // Примечание про Pro
                        HStack(spacing: 8) {
                            Image(systemName: isPro ? "checkmark.seal.fill" : "lock.fill")
                            Text(isPro ? "All editor features unlocked." : "Some tools require Pro.")
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 20)

                        Spacer(minLength: 90)
                    }
                    .padding(.bottom, 16)
                }
            }
            .brandBackground()   
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("") // хидер рисуем сами

            .sheet(isPresented: $showPaywall) { PaywallContainer() }

            .navigationDestination(for: EditorRoute.self) { route in
                switch route {
                case .filters:   FiltersScreen()
                case .covers:    CoversScreen()                 
                case .watermark: WatermarkScreen()
                case .resize:    ResizeScreen()
                case .avatars:   AvatarGenerationScreen()
                }
            }
        }
    }

    // MARK: - Routing helper
    private func navigate(_ route: EditorRoute) {
        if isPro { path.append(route) } else { showPaywall = true }
    }

    // MARK: - UI: плитка-фичи в стиле Post Planner
    private func featureCard(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text(isPro ? "Open" : "Go Pro")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
