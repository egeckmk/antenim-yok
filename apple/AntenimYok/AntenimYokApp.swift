import AntenimYokCore
import SwiftUI

@main
struct AntenimYokApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("Antenim Yok", id: MacWindow.main) {
            RootView()
                .environment(model)
                .preferredColorScheme(model.theme.colorScheme)
                .frame(minWidth: 520, minHeight: 420)
                .modifier(PlaybackKeys(model: model))
        }
        .defaultSize(width: 880, height: 620)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("İstasyon Ara") { model.focusSearch() }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("Oynatma") {
                PlaybackCommands(model: model)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.flushSettings() }
        }

        Window("Mini oynatıcı", id: MacWindow.mini) {
            MiniPlayerView(model: model)
                .environment(model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra("Antenim Yok", systemImage: model.menuBarSymbol) {
            MenuBarContent(model: model)
        }
        #else
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.flushSettings() }
        }
        #endif
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: "Sistem"
        case .light: "Açık"
        case .dark: "Koyu"
        }
    }
}
