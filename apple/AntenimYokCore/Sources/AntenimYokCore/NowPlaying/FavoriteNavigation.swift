import Foundation

/// Next/previous "track" for media keys, Control Center and AirPods: the neighbouring favorite.
public enum FavoriteNavigation {
    /// The favorite `offset` places after (positive) or before (negative) the current station, wrapping around.
    /// When `currentId` is nil or not a favorite, returns the first favorite. Empty list: nil.
    public static func adjacent(in favorites: [Station], currentId: String?, offset: Int) -> Station? {
        guard !favorites.isEmpty else { return nil }
        guard let currentId, let index = favorites.firstIndex(where: { $0.id == currentId }) else {
            return favorites[0]
        }
        let count = favorites.count
        let wrapped = ((index + offset) % count + count) % count
        return favorites[wrapped]
    }
}
