#if os(macOS)
import AntenimYokCore
import AppKit
import SwiftUI

/// Window ids of the Mac scenes.
enum MacWindow {
    static let main = "main"
    static let mini = "mini"
}

/// Closing the last window keeps the app (and the radio) alive in the menu bar, unless the user turned that off.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the app once the model exists.
    @MainActor static var keepPlayingInMenuBar: () -> Bool = { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated {
            MenuBarMenu.quitsWhenLastWindowCloses(keepPlayingInMenuBar: Self.keepPlayingInMenuBar())
        }
    }
}

/// The menu bar menu: favorites (the playing one marked), play/stop, show window, quit.
struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(Array(model.menuBarItems.enumerated()), id: \.offset) { _, item in
            switch item {
            case .station(let id, let name, let isPlaying):
                Button {
                    if let station = model.favorites.first(where: { $0.id == id }) { model.play(station) }
                } label: {
                    if isPlaying {
                        Label(name, systemImage: "speaker.wave.2.fill")
                    } else {
                        Text(name)
                    }
                }
            case .playPause(let title, let isEnabled):
                Button(title) { model.togglePlayback() }.disabled(!isEnabled)
            case .showWindow:
                Button("Pencereyi göster") { showMainWindow() }
            case .quit:
                Button("Çıkış") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            case .separator:
                Divider()
            }
        }
    }

    private func showMainWindow() {
        openWindow(id: MacWindow.main)
        NSApplication.shared.activate()
    }
}

extension AppModel {
    var menuBarSymbol: String {
        player.isActive ? "dot.radiowaves.left.and.right" : "radio"
    }
}
#endif
