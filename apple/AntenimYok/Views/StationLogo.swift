import AntenimYokCore
import SwiftUI

/// Square station logo; the station's initials show until (or instead of) the image.
struct StationLogo: View {
    let station: Station

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
            Text(station.initials)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let logo = station.logo, let url = URL(string: logo) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}
