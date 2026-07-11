import Foundation

struct PluginActivityPresentation: Codable, Equatable, Hashable, Sendable {
    let title: String
    let value: String
    let systemImage: String

    private enum CodingKeys: String, CodingKey {
        case title = "t"
        case value = "v"
        case icon = "s"
    }

    private enum ActivityIcon: UInt8 {
        case puzzle
        case calendar
        case book
        case bell
        case star
        case weather
        case clock
        case info

        init(systemImage: String) {
            self = switch systemImage {
            case "calendar", "calendar.badge.clock": .calendar
            case "book", "book.closed", "book.closed.fill": .book
            case "bell", "bell.fill", "bell.badge": .bell
            case "star", "star.fill", "sparkles": .star
            case "cloud.sun", "cloud.sun.fill", "sun.max", "sun.max.fill": .weather
            case "clock", "clock.fill", "timer": .clock
            case "info.circle", "info.circle.fill": .info
            default: .puzzle
            }
        }

        var systemImage: String {
            switch self {
            case .puzzle: "puzzlepiece.extension"
            case .calendar: "calendar"
            case .book: "book.closed.fill"
            case .bell: "bell.fill"
            case .star: "sparkles"
            case .weather: "cloud.sun.fill"
            case .clock: "clock.fill"
            case .info: "info.circle.fill"
            }
        }
    }

    init(title: String, value: String, systemImage: String) {
        self.title = Self.clippedUTF8(title, maximumBytes: 24)
        self.value = Self.clippedUTF8(value, maximumBytes: 48)
        self.systemImage = Self.clippedUTF8(systemImage, maximumBytes: 48)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = Self.clippedUTF8(
            try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            maximumBytes: 24
        )
        value = Self.clippedUTF8(
            try container.decodeIfPresent(String.self, forKey: .value) ?? "",
            maximumBytes: 48
        )
        let icon = try container.decodeIfPresent(UInt8.self, forKey: .icon)
            .flatMap { ActivityIcon(rawValue: $0) } ?? .puzzle
        systemImage = icon.systemImage
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(value, forKey: .value)
        try container.encode(ActivityIcon(systemImage: systemImage).rawValue, forKey: .icon)
    }

    private static func clippedUTF8(_ value: String, maximumBytes: Int) -> String {
        var result = ""
        var byteCount = 0
        for character in value {
            let characterBytes = String(character).utf8.count
            guard byteCount + characterBytes <= maximumBytes else { break }
            result.append(character)
            byteCount += characterBytes
        }
        return result
    }
}
