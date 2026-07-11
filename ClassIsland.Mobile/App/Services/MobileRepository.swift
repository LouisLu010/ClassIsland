import Foundation

struct MobileRepository: Sendable {
    private enum StorageLocation {
        case documents
        case applicationSupport
    }

    private let fileManager: FileManager
    private let rootDirectory: URL?
    private let documentsDirectoryOverride: URL?

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        documentsDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
        documentsDirectoryOverride = documentsDirectory ?? rootDirectory
    }

    func loadProfileData() throws -> Data? {
        try loadData(named: "Profile.json", from: .documents)
    }

    func saveProfileData(_ data: Data) throws {
        try saveData(data, named: "Profile.json", to: .documents)
    }

    func loadSettings() throws -> MobileSettings? {
        guard let data = try loadData(
            named: "MobileSettings.json",
            from: .documents
        ) else { return nil }
        return try JSONDecoder().decode(MobileSettings.self, from: data)
    }

    func saveSettings(_ settings: MobileSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try saveData(
            encoder.encode(settings),
            named: "MobileSettings.json",
            to: .documents
        )
    }

    func loadWeather() throws -> WeatherSnapshot? {
        guard let data = try loadData(
            named: "WeatherCache.json",
            from: .applicationSupport
        ) else { return nil }
        return try JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    func saveWeather(_ weather: WeatherSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try saveData(
            encoder.encode(weather),
            named: "WeatherCache.json",
            to: .applicationSupport
        )
    }

    func loadPluginScheduleCheckpoint() throws -> MobilePluginScheduleCheckpoint? {
        guard let data = try loadData(
            named: "MobilePluginScheduleCheckpoint.json",
            from: .applicationSupport
        ) else {
            return nil
        }
        return try JSONDecoder().decode(MobilePluginScheduleCheckpoint.self, from: data)
    }

    func savePluginScheduleCheckpoint(_ checkpoint: MobilePluginScheduleCheckpoint?) throws {
        guard let checkpoint else {
            try removeData(
                named: "MobilePluginScheduleCheckpoint.json",
                from: .applicationSupport
            )
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try saveData(
            encoder.encode(checkpoint),
            named: "MobilePluginScheduleCheckpoint.json",
            to: .applicationSupport
        )
    }

    func removeProfile() throws {
        try removeData(named: "Profile.json", from: .documents)
    }

    private func loadData(
        named fileName: String,
        from location: StorageLocation
    ) throws -> Data? {
        let url = try fileURL(named: fileName, in: location)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func saveData(
        _ data: Data,
        named fileName: String,
        to location: StorageLocation
    ) throws {
        let target = try fileURL(named: fileName, in: location)
        let directory = target.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(
            ".\(fileName).\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporary) }
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: target)
        }
    }

    private func removeData(
        named fileName: String,
        from location: StorageLocation
    ) throws {
        let url = try fileURL(named: fileName, in: location)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func fileURL(named fileName: String, in location: StorageLocation) throws -> URL {
        switch location {
        case .documents:
            return try migratedDocumentURL(named: fileName)
        case .applicationSupport:
            return try applicationSupportDirectory().appendingPathComponent(fileName)
        }
    }

    private func migratedDocumentURL(named fileName: String) throws -> URL {
        let target = try documentsDirectory().appendingPathComponent(fileName)
        let legacy = try applicationSupportDirectory().appendingPathComponent(fileName)
        guard target.standardizedFileURL != legacy.standardizedFileURL,
              !fileManager.fileExists(atPath: target.path),
              fileManager.fileExists(atPath: legacy.path) else {
            return target
        }

        try fileManager.moveItem(at: legacy, to: target)
        return target
    }

    private func documentsDirectory() throws -> URL {
        if let documentsDirectoryOverride {
            return try ensureDirectory(documentsDirectoryOverride)
        }
        let directory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try ensureDirectory(directory)
    }

    private func applicationSupportDirectory() throws -> URL {
        if let rootDirectory {
            return try ensureDirectory(rootDirectory)
        }
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try ensureDirectory(root.appendingPathComponent("ClassIsland", isDirectory: true))
    }

    private func ensureDirectory(_ url: URL) throws -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
