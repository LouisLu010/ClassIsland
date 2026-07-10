import Foundation
import SwiftUI

struct MobileSettings: Codable, Equatable, Sendable {
    var liveActivitiesEnabled = true
    var showTeacher = true
    var showCurrentLessonOnlyOnClass = false
    var useInitialInCompactIsland = true
    var keepAfterSchoolActivity = false
    var appearance = AppearancePreference.system
    var accent = AccentPreference.classIslandBlue
    var importedAccentHex: String?
    var singleWeekStartTime: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dotNetWeekday = calendar.component(.weekday, from: today) - 1
        return calendar.date(byAdding: .day, value: -dotNetWeekday, to: today) ?? today
    }()
    var rotationOffsets = [-1, -1, 0, 0, 0]
    var maxRotationCycle = 4

    private enum CodingKeys: String, CodingKey {
        case liveActivitiesEnabled
        case showTeacher
        case showCurrentLessonOnlyOnClass
        case useInitialInCompactIsland
        case keepAfterSchoolActivity
        case appearance
        case accent
        case importedAccentHex
        case singleWeekStartTime
        case rotationOffsets
        case maxRotationCycle
    }

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = MobileSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        liveActivitiesEnabled = (try? container.decode(Bool.self, forKey: .liveActivitiesEnabled))
            ?? defaults.liveActivitiesEnabled
        showTeacher = (try? container.decode(Bool.self, forKey: .showTeacher)) ?? defaults.showTeacher
        showCurrentLessonOnlyOnClass = (try? container.decode(Bool.self, forKey: .showCurrentLessonOnlyOnClass))
            ?? defaults.showCurrentLessonOnlyOnClass
        useInitialInCompactIsland = (try? container.decode(Bool.self, forKey: .useInitialInCompactIsland))
            ?? defaults.useInitialInCompactIsland
        keepAfterSchoolActivity = (try? container.decode(Bool.self, forKey: .keepAfterSchoolActivity))
            ?? defaults.keepAfterSchoolActivity
        appearance = (try? container.decode(AppearancePreference.self, forKey: .appearance)) ?? defaults.appearance
        accent = (try? container.decode(AccentPreference.self, forKey: .accent)) ?? defaults.accent
        importedAccentHex = try? container.decode(String.self, forKey: .importedAccentHex)
        singleWeekStartTime = (try? container.decode(Date.self, forKey: .singleWeekStartTime))
            ?? defaults.singleWeekStartTime
        rotationOffsets = (try? container.decode([Int].self, forKey: .rotationOffsets))
            ?? defaults.rotationOffsets
        maxRotationCycle = min(
            max((try? container.decode(Int.self, forKey: .maxRotationCycle)) ?? defaults.maxRotationCycle, 2),
            12
        )

        if rotationOffsets.count < 2 {
            rotationOffsets = defaults.rotationOffsets
        } else if rotationOffsets.count > 2 {
            for cycle in 2..<rotationOffsets.count {
                rotationOffsets[cycle] = min(max(rotationOffsets[cycle], 0), cycle - 1)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(liveActivitiesEnabled, forKey: .liveActivitiesEnabled)
        try container.encode(showTeacher, forKey: .showTeacher)
        try container.encode(showCurrentLessonOnlyOnClass, forKey: .showCurrentLessonOnlyOnClass)
        try container.encode(useInitialInCompactIsland, forKey: .useInitialInCompactIsland)
        try container.encode(keepAfterSchoolActivity, forKey: .keepAfterSchoolActivity)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(accent, forKey: .accent)
        try container.encodeIfPresent(importedAccentHex, forKey: .importedAccentHex)
        try container.encode(singleWeekStartTime, forKey: .singleWeekStartTime)
        try container.encode(rotationOffsets, forKey: .rotationOffsets)
        try container.encode(maxRotationCycle, forKey: .maxRotationCycle)
    }

    var accentColor: Color {
        guard let importedAccentHex,
              let color = Self.color(hex: importedAccentHex) else {
            return accent.color
        }
        return color
    }

    func rotationOffset(for cycle: Int) -> Int {
        guard cycle >= 0, cycle < rotationOffsets.count else { return 0 }
        return rotationOffsets[cycle]
    }

    mutating func setRotationOffset(_ value: Int, for cycle: Int) {
        guard cycle >= 2 else { return }
        while rotationOffsets.count <= cycle {
            rotationOffsets.append(0)
        }
        rotationOffsets[cycle] = min(max(value, 0), cycle - 1)
    }

    private static func color(hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let redShift = cleaned.count == 8 ? 24 : 16
        let greenShift = cleaned.count == 8 ? 16 : 8
        let blueShift = cleaned.count == 8 ? 8 : 0
        let red = Double((value >> redShift) & 0xFF) / 255
        let green = Double((value >> greenShift) & 0xFF) / 255
        let blue = Double((value >> blueShift) & 0xFF) / 255
        let alpha = cleaned.count == 8 ? Double(value & 0xFF) / 255 : 1
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AccentPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case classIslandBlue
    case mint
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classIslandBlue: "ClassIsland 蓝"
        case .mint: "薄荷绿"
        case .orange: "活力橙"
        }
    }

    var color: Color {
        switch self {
        case .classIslandBlue: Color(red: 0.02, green: 0.67, blue: 0.91)
        case .mint: Color(red: 0.12, green: 0.72, blue: 0.55)
        case .orange: Color(red: 0.96, green: 0.45, blue: 0.14)
        }
    }
}

struct ClassIslandWindowsSettings: Decodable, Sendable {
    let selectedProfile: String?
    let singleWeekStartTime: String?
    let multiWeekRotationOffset: [Int]?
    let multiWeekRotationMaxCycle: Int?
    let theme: Int?
    let colorSource: Int?
    let primaryColor: String?
    let selectedPalette: String?
    let showCurrentLessonOnlyOnClass: Bool?

    enum CodingKeys: String, CodingKey {
        case selectedProfile = "SelectedProfile"
        case singleWeekStartTime = "SingleWeekStartTime"
        case multiWeekRotationOffset = "MultiWeekRotationOffset"
        case multiWeekRotationMaxCycle = "MultiWeekRotationMaxCycle"
        case theme = "Theme"
        case colorSource = "ColorSource"
        case primaryColor = "PrimaryColor"
        case selectedPalette = "SelectedPlatte"
        case showCurrentLessonOnlyOnClass = "ShowCurrentLessonOnlyOnClass"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedProfile = try? container.decode(String.self, forKey: .selectedProfile)
        singleWeekStartTime = try? container.decode(String.self, forKey: .singleWeekStartTime)
        multiWeekRotationOffset = try? container.decode([Int].self, forKey: .multiWeekRotationOffset)
        multiWeekRotationMaxCycle = try? container.decode(Int.self, forKey: .multiWeekRotationMaxCycle)
        theme = try? container.decode(Int.self, forKey: .theme)
        colorSource = try? container.decode(Int.self, forKey: .colorSource)
        showCurrentLessonOnlyOnClass = try? container.decode(Bool.self, forKey: .showCurrentLessonOnlyOnClass)
        primaryColor = Self.decodeColor(from: container, forKey: .primaryColor)
        selectedPalette = Self.decodeColor(from: container, forKey: .selectedPalette)
    }

    private static func decodeColor(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let hex = try? container.decode(String.self, forKey: key) {
            return hex
        }
        guard let color = try? container.decode(LegacyColor.self, forKey: key) else { return nil }
        return String(format: "#%02X%02X%02X%02X", color.red, color.green, color.blue, color.alpha)
    }

    private struct LegacyColor: Decodable {
        let alpha: UInt8
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        enum CodingKeys: String, CodingKey {
            case alpha = "A"
            case red = "R"
            case green = "G"
            case blue = "B"
        }
    }
}
