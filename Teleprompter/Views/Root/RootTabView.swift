import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    private enum AppTab: Hashable {
        case home
        case videos
        case mine
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .tabItem {
                    Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
                }

            VideosView()
                .tag(AppTab.videos)
                .tabItem {
                    Label("Videos", systemImage: selectedTab == .videos ? "play.rectangle.fill" : "play.rectangle")
                }

            MineView()
                .tag(AppTab.mine)
                .tabItem {
                    Label("Mine", systemImage: selectedTab == .mine ? "person.crop.circle.fill" : "person.crop.circle")
                }
        }
        .tint(.creatorViolet)
    }
}
