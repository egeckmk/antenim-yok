import Foundation

/// A rectangle in screen coordinates (origin = bottom-left corner, as on the Mac).
public struct PlacementRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }

    func intersectionArea(with other: PlacementRect) -> Double {
        let w = min(maxX, other.maxX) - max(x, other.x)
        let h = min(maxY, other.maxY) - max(y, other.y)
        return w > 0 && h > 0 ? w * h : 0
    }
}

/// Where the mini player window goes: the remembered position, kept fully on a screen
/// (the monitor may have been unplugged or the resolution changed), else the bottom-right corner.
public enum MiniPlayerPlacement {
    public static let margin: Double = 24

    /// `visibleFrames`: the usable area of each screen (without menu bar and Dock), main screen first.
    public static func origin(
        saved: WindowPosition?,
        size: (width: Double, height: Double),
        visibleFrames: [PlacementRect]
    ) -> WindowPosition? {
        guard let first = visibleFrames.first else { return saved }

        if let saved {
            let window = PlacementRect(x: saved.x, y: saved.y, width: size.width, height: size.height)
            let best = visibleFrames
                .map { ($0, $0.intersectionArea(with: window)) }
                .max { $0.1 < $1.1 }
            if let (frame, area) = best, area > 0 {
                return clamp(saved, size: size, in: frame)
            }
        }
        return WindowPosition(
            x: first.maxX - size.width - margin,
            y: first.y + margin)
    }

    private static func clamp(_ position: WindowPosition, size: (width: Double, height: Double), in frame: PlacementRect) -> WindowPosition {
        WindowPosition(
            x: min(max(position.x, frame.x), max(frame.x, frame.maxX - size.width)),
            y: min(max(position.y, frame.y), max(frame.y, frame.maxY - size.height)))
    }
}
