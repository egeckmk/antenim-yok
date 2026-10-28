import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case favorites
    case discover
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: "Favoriler"
        case .discover: "Keşfet"
        case .settings: "Ayarlar"
        }
    }

    var symbol: String {
        switch self {
        case .favorites: "star.fill"
        case .discover: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}
