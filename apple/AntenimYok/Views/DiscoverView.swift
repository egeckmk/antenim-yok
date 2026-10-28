import AntenimYokCore
import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var discover = model.discover
        @Bindable var model = model
        Group {
            switch discover.phase {
            case .idle, .loading:
                ProgressView("Radyolar yükleniyor…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Radyolar yüklenemedi", systemImage: "wifi.slash")
                } description: {
                    Text("İnternet bağlantını kontrol edip tekrar dene.")
                } actions: {
                    Button("Tekrar dene") { Task { await discover.load() } }
                        .buttonStyle(.borderedProminent)
                }
            case .loaded:
                List {
                    Section {
                        ForEach(discover.results) { found in
                            DiscoverRow(found: found)
                        }
                    } header: {
                        Text(discover.countText)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if discover.results.isEmpty {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                }
            }
        }
        .navigationTitle("Keşfet")
        .searchable(text: $model.searchText, prompt: "Radyo ara")
        .searchFocused($searchFocused)
        .onChange(of: model.wantsSearchFocus, initial: true) { _, wants in
            guard wants else { return }
            searchFocused = true
            model.wantsSearchFocus = false
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if discover.phase == .loaded {
                GenreBar(selection: $discover.genre)
            }
        }
        .task { await model.discover.ensureLoaded() }
        .onChange(of: model.searchText, initial: true) { _, text in
            model.discover.query = text
        }
    }
}

private struct GenreBar: View {
    @Binding var selection: Genre

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Genre.defaults) { genre in
                    Button(genre.name) { selection = genre }
                        .buttonStyle(.bordered)
                        .tint(genre == selection ? .accentColor : .secondary)
                        .controlSize(.regular)
                        .accessibilityAddTraits(genre == selection ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct DiscoverRow: View {
    @Environment(AppModel.self) private var model
    let found: DiscoveredStation

    var body: some View {
        let station = found.station
        let isPlaying = model.isPlaying(station)
        let isFavorite = model.isFavorite(station)
        HStack(spacing: 12) {
            Button {
                model.toggle(station)
            } label: {
                HStack(spacing: 12) {
                    StationLogo(station: station)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundStyle(isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        if !found.summary.isEmpty {
                            Text(found.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(station.name)
            .accessibilityValue(isPlaying ? "Çalıyor" : found.summary)

            Button {
                model.toggleFavorite(station)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")
        }
    }
}
