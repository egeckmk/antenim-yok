import AntenimYokCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Görünüm") {
                Picker("Tema", selection: $model.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }
            Section {
                Toggle("Şarkı adlarını göster", isOn: $model.showSongTitles)
            } header: {
                Text("Çalma")
            } footer: {
                Text("Destekleyen istasyonlarda çalan şarkı adı gösterilir. Açıkken yayına ikinci bir bağlantı açılır.")
            }
            #if os(macOS)
            Section {
                Toggle("Kapatınca menü çubuğunda çalmaya devam et", isOn: $model.keepPlayingInMenuBar)
            } header: {
                Text("Pencere")
            } footer: {
                Text("Kapalıyken son pencereyi kapatmak uygulamayı da kapatır.")
            }
            Section("Klavye kısayolları") {
                LabeledContent("Çal / durdur", value: "Boşluk")
                LabeledContent("1.–9. favoriyi çal", value: "⌘1 … ⌘9")
                LabeledContent("İstasyon ara", value: "⌘F")
                LabeledContent("Sesi artır / azalt", value: "⌘↑ / ⌘↓")
                LabeledContent("Sessiz", value: "M  ·  ⌥⌘↓")
            }
            #endif
            Section("Hakkında") {
                LabeledContent("Sürüm", value: Self.version)
                LabeledContent("Lisans", value: "GPL-3.0")
                Text("Reklamsız radyo. Favorileriniz yalnızca bu cihazda saklanır.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ayarlar")
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
