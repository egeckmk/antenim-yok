import AntenimYokCore
import SwiftUI

@main
struct AntenimYokApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.theme.colorScheme)
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 420)
                .modifier(PlaybackKeys())
                #endif
        }
        #if os(macOS)
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
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.flushSettings() }
        }
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
