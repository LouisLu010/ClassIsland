import Foundation
import SwiftUI

enum ReminderSurface: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case dynamicIsland
    case liveActivity
    case systemNotification

    var id: Self { self }

    var title: String {
        switch self {
        case .dynamicIsland: "灵动岛"
        case .liveActivity: "实时活动"
        case .systemNotification: "系统通知"
        }
    }
}

struct MobileSettings: Codable, Equatable, Sendable {
    static let timeOffsetRange = -300.0...300.0
    static let defaultWeatherCityID = "weathercn:101010100"
    static let defaultWeatherCityName = "北京市 (中国)"

    var hasCompletedOnboarding = false
    var reminderSurfaces: Set<ReminderSurface> = [.dynamicIsland, .liveActivity]
    var showTeacher = true
    var showCurrentLessonOnlyOnClass = false
    var useInitialInCompactIsland = true
    var keepAfterSchoolActivity = false
    var liveActivityLayout = LiveActivityLayout.default
    var weatherEnabled = true
    var weatherCityID = Self.defaultWeatherCityID
    var weatherCityName = Self.defaultWeatherCityName
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
    var timeOffsetSeconds = 0.0

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case reminderSurfaces
        case liveActivitiesEnabled
        case showTeacher
        case showCurrentLessonOnlyOnClass
        case useInitialInCompactIsland
        case keepAfterSchoolActivity
        case liveActivityLayout
        case weatherEnabled
        case weatherCityID
        case weatherCityName
        case appearance
        case accent
        case importedAccentHex
        case singleWeekStartTime
        case rotationOffsets
        case maxRotationCycle
        case timeOffsetSeconds
    }

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = MobileSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding))
            ?? defaults.hasCompletedOnboarding
        if let decodedSurfaces = try? container.decode(Set<ReminderSurface>.self, forKey: .reminderSurfaces) {
            reminderSurfaces = decodedSurfaces
        } else {
            let legacyEnabled = (try? container.decode(Bool.self, forKey: .liveActivitiesEnabled))
                ?? defaults.liveActivitiesEnabled
            reminderSurfaces = legacyEnabled ? defaults.reminderSurfaces : []
        }
        showTeacher = (try? container.decode(Bool.self, forKey: .showTeacher)) ?? defaults.showTeacher
        showCurrentLessonOnlyOnClass = (try? container.decode(Bool.self, forKey: .showCurrentLessonOnlyOnClass))
            ?? defaults.showCurrentLessonOnlyOnClass
        useInitialInCompactIsland = (try? container.decode(Bool.self, forKey: .useInitialInCompactIsland))
            ?? defaults.useInitialInCompactIsland
        keepAfterSchoolActivity = (try? container.decode(Bool.self, forKey: .keepAfterSchoolActivity))
            ?? defaults.keepAfterSchoolActivity
        liveActivityLayout = (try? container.decode(LiveActivityLayout.self, forKey: .liveActivityLayout))
            ?? defaults.liveActivityLayout
        weatherEnabled = (try? container.decode(Bool.self, forKey: .weatherEnabled))
            ?? defaults.weatherEnabled
        let decodedWeatherCityID = (try? container.decode(String.self, forKey: .weatherCityID))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        weatherCityID = decodedWeatherCityID.flatMap { $0.isEmpty ? nil : $0 }
            ?? defaults.weatherCityID
        let decodedWeatherCityName = (try? container.decode(String.self, forKey: .weatherCityName))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        weatherCityName = decodedWeatherCityName.flatMap { $0.isEmpty ? nil : $0 }
            ?? defaults.weatherCityName
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
        timeOffsetSeconds = Self.clampedTimeOffset(
            (try? container.decode(Double.self, forKey: .timeOffsetSeconds))
                ?? defaults.timeOffsetSeconds
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
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(
            ReminderSurface.allCases.filter { reminderSurfaces.contains($0) },
            forKey: .reminderSurfaces
        )
        try container.encode(liveActivitiesEnabled, forKey: .liveActivitiesEnabled)
        try container.encode(showTeacher, forKey: .showTeacher)
        try container.encode(showCurrentLessonOnlyOnClass, forKey: .showCurrentLessonOnlyOnClass)
        try container.encode(useInitialInCompactIsland, forKey: .useInitialInCompactIsland)
        try container.encode(keepAfterSchoolActivity, forKey: .keepAfterSchoolActivity)
        try container.encode(liveActivityLayout, forKey: .liveActivityLayout)
        try container.encode(weatherEnabled, forKey: .weatherEnabled)
        try container.encode(weatherCityID, forKey: .weatherCityID)
        try container.encode(weatherCityName, forKey: .weatherCityName)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(accent, forKey: .accent)
        try container.encodeIfPresent(importedAccentHex, forKey: .importedAccentHex)
        try container.encode(singleWeekStartTime, forKey: .singleWeekStartTime)
        try container.encode(rotationOffsets, forKey: .rotationOffsets)
        try container.encode(maxRotationCycle, forKey: .maxRotationCycle)
        try container.encode(timeOffsetSeconds, forKey: .timeOffsetSeconds)
    }

    var accentColor: Color {
        guard let importedAccentHex,
              let color = Self.color(hex: importedAccentHex) else {
            return accent.color
        }
        return color
    }

    var liveActivitiesEnabled: Bool {
        get {
            reminderSurfaces.contains(.dynamicIsland)
                || reminderSurfaces.contains(.liveActivity)
        }
        set {
            if newValue {
                reminderSurfaces.formUnion([.dynamicIsland, .liveActivity])
            } else {
                reminderSurfaces.subtract([.dynamicIsland, .liveActivity])
            }
        }
    }

    var systemNotificationsEnabled: Bool {
        reminderSurfaces.contains(.systemNotification)
    }

    var activityAccentRGBA: UInt32 {
        if let importedAccentHex,
           let value = Self.rgba(hex: importedAccentHex) {
            return value
        }
        return switch accent {
        case .classIslandBlue: 0x05ABE8FF
        case .mint: 0x1FB88CFF
        case .orange: 0xF57324FF
        }
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

    static func clampedTimeOffset(_ value: Double) -> Double {
        min(max(value, timeOffsetRange.lowerBound), timeOffsetRange.upperBound)
    }

    private static func color(hex: String) -> Color? {
        guard let value = rgba(hex: hex) else { return nil }
        let red = Double((value >> 24) & 0xFF) / 255
        let green = Double((value >> 16) & 0xFF) / 255
        let blue = Double((value >> 8) & 0xFF) / 255
        let alpha = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func rgba(hex: String) -> UInt32? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt32(cleaned, radix: 16) else {
            return nil
        }
        return cleaned.count == 8 ? value : value << 8 | 0xFF
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
    let timeOffsetSeconds: Double?
    let cityID: String?
    let cityName: String?

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
        case timeOffsetSeconds = "TimeOffsetSeconds"
        case cityID = "CityId"
        case cityName = "CityName"
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
        timeOffsetSeconds = try? container.decode(Double.self, forKey: .timeOffsetSeconds)
        cityID = try? container.decode(String.self, forKey: .cityID)
        cityName = try? container.decode(String.self, forKey: .cityName)
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
