import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        #if os(macOS)
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            NavigationStack {
                SectionView(section: model.section)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                NowPlayingBar()
            }
        }
        #else
        TabView(selection: $model.section) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.symbol, value: section) {
                    NavigationStack {
                        SectionView(section: section)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        NowPlayingBar()
                    }
                }
            }
        }
        #endif
    }
}

private struct SectionView: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .favorites: FavoritesView()
        case .discover: DiscoverView()
        case .settings: SettingsView()
        }
    }
}
