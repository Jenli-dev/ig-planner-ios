import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var purchases: PurchaseManager

    var body: some View {
        TabView {
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Analytics")
                }

            PostPlannerView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Post Planner")
                }

            // NEW: Photo Editor hub
            PhotoEditorHubView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Photo Editor")
                }

            AvatarGenerationScreen()
                .tabItem {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Avatars")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
    }
}
