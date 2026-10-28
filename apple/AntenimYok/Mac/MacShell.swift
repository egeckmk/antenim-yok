#if os(macOS)
import AntenimYokCore
import AppKit
import ServiceManagement
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

    /// True when macOS started the app because the user logged in (the "launch at login" item).
    @MainActor private(set) static var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginItem = event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        MainActor.assumeIsolated { Self.launchedAtLogin = isLoginItem }
    }

    /// Started at login: no window, only the menu bar item (the windows are hidden, not closed, so "Pencereyi göster" reuses them).
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard MainActor.assumeIsolated({ Self.launchedAtLogin }) else { return }
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows where window.canBecomeMain {
                window.orderOut(nil)
            }
        }
    }

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

/// "Oturum açılınca başlat" via `SMAppService.mainApp` (macOS 13+). Registration may need a signed build.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool
    private(set) var needsApproval = false
    private(set) var errorMessage: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Değiştirilemedi. Uygulama imzalı olmalı ve Uygulamalar klasöründe durmalı."
        }
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }
}

extension AppModel {
    var menuBarSymbol: String {
        player.isActive ? "dot.radiowaves.left.and.right" : "radio"
    }
}
#endif
