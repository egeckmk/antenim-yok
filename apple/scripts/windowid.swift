import CoreGraphics
import Foundation

// usage: swift windowid.swift <owner name>  -> prints the id of that app's biggest normal window
let owner = CommandLine.arguments[1]
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
let best = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == owner && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .max { area($0) < area($1) }
func area(_ w: [String: Any]) -> Double {
    guard let b = w[kCGWindowBounds as String] as? [String: Double] else { return 0 }
    return (b["Width"] ?? 0) * (b["Height"] ?? 0)
}
if let id = best?[kCGWindowNumber as String] as? Int { print(id) } else { exit(1) }
