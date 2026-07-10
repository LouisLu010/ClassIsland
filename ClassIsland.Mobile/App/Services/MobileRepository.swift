import Foundation

struct MobileRepository: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadProfileData() throws -> Data? {
        try loadData(named: "Profile.json")
    }

    func saveProfileData(_ data: Data) throws {
        try saveData(data, named: "Profile.json")
    }

    func loadSettings() throws -> MobileSettings? {
        guard let data = try loadData(named: "MobileSettings.json") else { return nil }
        return try JSONDecoder().decode(MobileSettings.self, from: data)
    }

    func saveSettings(_ settings: MobileSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try saveData(encoder.encode(settings), named: "MobileSettings.json")
    }

    func removeProfile() throws {
        let url = try applicationSupportDirectory().appendingPathComponent("Profile.json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func loadData(named fileName: String) throws -> Data? {
        let url = try applicationSupportDirectory().appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func saveData(_ data: Data, named fileName: String) throws {
        let directory = try applicationSupportDirectory()
        let target = directory.appendingPathComponent(fileName)
        let temporary = directory.appendingPathComponent(".\(fileName).tmp")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: target)
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("ClassIsland", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
