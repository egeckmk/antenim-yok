import AntenimYokCore
import SwiftUI

struct FavoritesView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 16)]

    var body: some View {
        @Bindable var model = model
        Group {
            if model.favorites.isEmpty {
                ContentUnavailableView {
                    Label("Henüz favori yok", systemImage: "star")
                } description: {
                    Text("Keşfet'ten istasyon bulup yıldızla ekleyebilirsin.")
                } actions: {
                    Button("Keşfet'e git") { model.section = .discover }
                        .buttonStyle(.borderedProminent)
                }
            } else if model.visibleFavorites.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.visibleFavorites) { station in
                            StationCard(station: station)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favoriler")
        .searchable(text: $model.searchText, prompt: "Favorilerde ara")
    }
}

private struct StationCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let station: Station

    var body: some View {
        let isPlaying = model.isPlaying(station)
        Button {
            model.toggle(station)
        } label: {
            VStack(spacing: 8) {
                StationLogo(station: station)
                    .overlay {
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.tint, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                                .padding(4)
                                .background(.tint, in: .circle)
                                .foregroundStyle(.background)
                                .padding(4)
                        }
                    }
                Text(station.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(station.name)
        .accessibilityValue(isPlaying ? "Çalıyor" : "")
        .accessibilityHint(isPlaying ? "Durdurmak için çift dokunun" : "Çalmak için çift dokunun")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Favorilerden çıkar", systemImage: "star.slash", role: .destructive) {
                model.toggleFavorite(station)
            }
        }
    }
}

#Preview("Boş") {
    NavigationStack { FavoritesView() }
        .environment(AppModel())
}
