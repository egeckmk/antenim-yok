#if os(macOS)
import AppKit
import SwiftUI

/// The "Oynatma" menu: play/stop, volume, mute and ⌘1…9 for the first nine favorites.
struct PlaybackCommands: View {
    @Bindable var model: AppModel

    var body: some View {
        Button(model.player.isActive ? "Durdur" : "Çal") { model.togglePlayback() }
            .disabled(model.nowPlayingStation == nil)
        Divider()
        Button("Sesi Artır") { model.changeVolume(by: 1) }
            .keyboardShortcut(.upArrow, modifiers: .command)
        Button("Sesi Azalt") { model.changeVolume(by: -1) }
            .keyboardShortcut(.downArrow, modifiers: .command)
        Toggle("Sessiz", isOn: $model.isMuted)
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        if !model.favorites.isEmpty {
            Divider()
            ForEach(Array(model.favorites.prefix(9).enumerated()), id: \.element.id) { index, station in
                Button(station.name) { model.playFavorite(at: index) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
    }
}

/// Space = play/stop and M = mute, like the Windows app. These are plain keys, so they must yield to
/// text input: a `.keyboardShortcut` without modifiers would also fire while typing in the search field.
struct PlaybackKeys: ViewModifier {
    let model: AppModel
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    MainActor.assumeIsolated { handle(event) } ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers.isEmpty, !(event.window?.firstResponder is NSText) else { return false }
        switch event.charactersIgnoringModifiers {
        case " ": model.togglePlayback()
        case "m": model.isMuted.toggle()
        default: return false
        }
        return true
    }
}
#endif
