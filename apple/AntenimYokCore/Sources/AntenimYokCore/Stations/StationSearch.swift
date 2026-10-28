import Foundation

public enum StationSearch {
    /// Case- and accent-insensitive name match ("turk" finds "Power Türk", "İSTANBUL" finds "istanbul").
    /// Every word of the query must appear. A blank query matches everything.
    public static func matches(_ station: Station, query: String?) -> Bool {
        guard let query, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let name = fold(station.name)
        return fold(query)
            .split(separator: " ")
            .allSatisfy { name.contains($0) }
    }

    /// Lower case (Turkish rules), drop accents (ü->u, ş->s, ç->c, ğ->g, ö->o) and dotless ı->i.
    public static func fold(_ text: String) -> String {
        let lowered = text.lowercased(with: Locale(identifier: "tr_TR")).decomposedStringWithCanonicalMapping
        var result = String.UnicodeScalarView()
        for scalar in lowered.unicodeScalars where scalar.properties.generalCategory != .nonspacingMark {
            result.append(scalar == "ı" ? "i" : scalar)
        }
        return String(result)
    }
}
