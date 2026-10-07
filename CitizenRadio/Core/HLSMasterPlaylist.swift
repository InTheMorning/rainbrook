import Foundation

/// ADR 0020 §Stream quality: one variant of an HLS master playlist.
public struct HLSVariant: Equatable, Sendable {
    public let bandwidth: Int
    public let url: URL

    public init(bandwidth: Int, url: URL) {
        self.bandwidth = bandwidth
        self.url = url
    }
}

/// ADR 0020 §Stream quality: reads the variants of an HLS master playlist,
/// and selects the variant for a stream quality.
public enum HLSMasterPlaylist {
    private static let streamInfTag = "#EXT-X-STREAM-INF:"

    /// The variants of a master playlist, in file order. Each `#EXT-X-STREAM-INF` line with a
    /// whole-number BANDWIDTH and a URI on the next non-comment line gives one variant.
    /// A relative URI resolves against `baseURL`. Lines can end with CR LF.
    /// Gives an empty list for a text that is not a master playlist.
    public static func variants(in text: String, baseURL: URL) -> [HLSVariant] {
        // Swift reads CR LF as one newline character, so this step also removes CR.
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.first == "#EXTM3U" else { return [] }

        var result: [HLSVariant] = []
        // The bandwidth of the last stream tag. It waits for the URI line.
        var pendingBandwidth: Int?
        // The value is yes after a stream tag. Then the next URI line is the URI of that tag.
        var waitsForURI = false
        for line in lines {
            if line.hasPrefix(streamInfTag) {
                pendingBandwidth = bandwidth(in: String(line.dropFirst(streamInfTag.count)))
                waitsForURI = true
            } else if line.hasPrefix("#") {
                continue
            } else if waitsForURI {
                waitsForURI = false
                if let bandwidth = pendingBandwidth,
                   let url = URL(string: line, relativeTo: baseURL)?.absoluteURL {
                    result.append(HLSVariant(bandwidth: bandwidth, url: url))
                }
                pendingBandwidth = nil
            }
        }
        return result
    }

    /// The variant for the quality: high, the highest bandwidth. medium and low, the highest
    /// bandwidth at or below the maximum, else the lowest bandwidth. An empty list gives nil.
    public static func select(_ quality: StreamQuality, from variants: [HLSVariant]) -> HLSVariant? {
        guard !variants.isEmpty else { return nil }
        guard let maximum = quality.maximumBandwidth else {
            return variants.max { $0.bandwidth < $1.bandwidth }
        }
        let allowed = variants.filter { $0.bandwidth <= maximum }
        if let best = allowed.max(by: { $0.bandwidth < $1.bandwidth }) {
            return best
        }
        return variants.min { $0.bandwidth < $1.bandwidth }
    }

    /// The BANDWIDTH value of an attribute list, or nil when it is not a whole number.
    /// A comma in a quoted value does not end the attribute.
    private static func bandwidth(in attributes: String) -> Int? {
        var name = ""
        var value = ""
        var inValue = false
        var inQuotes = false
        var found: Int?
        func endAttribute() {
            if name.trimmingCharacters(in: .whitespaces) == "BANDWIDTH", found == nil,
               let number = Int(value), number >= 0 {
                found = number
            }
            name = ""
            value = ""
            inValue = false
        }
        for character in attributes {
            if inValue {
                if character == "\"" {
                    inQuotes.toggle()
                    value.append(character)
                } else if character == ",", !inQuotes {
                    endAttribute()
                } else {
                    value.append(character)
                }
            } else if character == "=" {
                inValue = true
            } else {
                name.append(character)
            }
        }
        endAttribute()
        return found
    }
}
