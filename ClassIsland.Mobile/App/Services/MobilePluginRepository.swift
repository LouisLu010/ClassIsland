import Foundation

struct MobilePluginRepository: Sendable {
    static let installationFileName = "installation.json"
    static let stateFileName = "state.json"

    private let fileManager: FileManager
    private let rootDirectory: URL?

    init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
    }

    func loadInstalledPlugins() throws -> [InstalledMobilePlugin] {
        var states: [String: MobilePluginState] = [:]
        for state in try loadStates() {
            states[state.id] = state
        }
        let directory = try pluginsDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { url in
            do {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                guard values.isDirectory == true else { return nil }
                let metadataURL = url.appendingPathComponent(Self.installationFileName)
                guard fileManager.fileExists(atPath: metadataURL.path) else { return nil }
                let installation = try decoder.decode(
                    MobilePluginInstallation.self,
                    from: Data(contentsOf: metadataURL)
                )
                guard installation.id == url.lastPathComponent else { return nil }
                let stateURL = url.appendingPathComponent(Self.stateFileName)
                var state: MobilePluginState
                if fileManager.fileExists(atPath: stateURL.path) {
                    state = try decoder.decode(
                        MobilePluginState.self,
                        from: Data(contentsOf: stateURL)
                    )
                } else {
                    state = states[installation.id] ?? MobilePluginState(
                        id: installation.id,
                        isEnabled: false,
                        grantedCapabilities: []
                    )
                }
                guard state.id == installation.id else { return nil }
                state.grantedCapabilities.formIntersection(
                    Set(installation.manifest.mobile.capabilities)
                )
                return InstalledMobilePlugin(installation: installation, state: state)
            } catch {
                return nil
            }
        }
        .sorted {
            $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending
        }
    }

    func saveState(_ state: MobilePluginState) throws {
        let directory = try pluginDirectory(id: state.id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw MobilePluginError.pluginNotFound
        }
        try saveJSON(state, to: directory.appendingPathComponent(Self.stateFileName))
    }

    func loadSettings(pluginID: String) throws -> [String: MobilePluginValue] {
        let url = try dataDirectory(pluginID: pluginID).appendingPathComponent("settings.json")
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        return try decoder.decode([String: MobilePluginValue].self, from: Data(contentsOf: url))
    }

    func saveSettings(_ values: [String: MobilePluginValue], pluginID: String) throws {
        try saveJSON(values, to: try dataDirectory(pluginID: pluginID).appendingPathComponent(
            "settings.json"
        ))
    }

    func stageImportedPackage(from sourceURL: URL) throws -> URL {
        let directory = try importsDirectory()
        let target = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("cipx")
        guard fileManager.createFile(atPath: target.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: target.path])
        }

        var succeeded = false
        defer {
            if !succeeded {
                try? fileManager.removeItem(at: target)
            }
        }
        let input = try FileHandle(forReadingFrom: sourceURL)
        let output = try FileHandle(forWritingTo: target)
        defer {
            try? input.close()
            try? output.close()
        }

        var copiedSize = 0
        while let chunk = try input.read(upToCount: 64 * 1_024), !chunk.isEmpty {
            copiedSize += chunk.count
            guard copiedSize <= MobilePluginPackageService.maximumPackageSize else {
                throw MobilePluginError.packageTooLarge
            }
            try output.write(contentsOf: chunk)
        }
        succeeded = true
        return target
    }

    func discardStagedPackage(at url: URL) {
        guard let directory = try? importsDirectory(),
              url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            return
        }
        try? fileManager.removeItem(at: url)
    }

    func discardAllStagedPackages() throws {
        let directory = try importsDirectory()
        for url in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            try fileManager.removeItem(at: url)
        }
    }

    func removePlugin(id: String, removeData: Bool = false) throws {
        let packageDirectory = try pluginDirectory(id: id)
        if fileManager.fileExists(atPath: packageDirectory.path) {
            try fileManager.removeItem(at: packageDirectory)
        }
        if removeData {
            let directory = try dataDirectory(pluginID: id)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    func iconURL(for installation: MobilePluginInstallation) throws -> URL? {
        guard let relativePath = installation.iconRelativePath else { return nil }
        let root = try pluginDirectory(id: installation.id).standardizedFileURL
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else { return nil }
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    func pluginsDirectory() throws -> URL {
        try ensureDirectory(
            try applicationSupportDirectory().appendingPathComponent("MobilePlugins", isDirectory: true)
        )
    }

    func pluginDirectory(id: String) throws -> URL {
        guard id == id.lowercased(),
              id.range(
                  of: "^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$",
                  options: .regularExpression
              ) != nil else {
            throw MobilePluginError.invalidPluginID
        }
        return try pluginsDirectory().appendingPathComponent(id, isDirectory: true)
    }

    func makeInstallationStagingDirectory() throws -> URL {
        let directory = try pluginsDirectory().appendingPathComponent(
            ".staging-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    func writeInstallation(
        _ installation: MobilePluginInstallation,
        state: MobilePluginState,
        to directory: URL
    ) throws {
        guard installation.id == state.id,
              state.grantedCapabilities.isSubset(
                  of: Set(installation.manifest.mobile.capabilities)
              ) else {
            throw MobilePluginError.invalidManifest("插件状态 ID 或授权与安装清单不一致。")
        }
        try saveJSON(
            installation,
            to: directory.appendingPathComponent(Self.installationFileName)
        )
        try saveJSON(state, to: directory.appendingPathComponent(Self.stateFileName))
    }

    func replacePluginDirectory(id: String, with stagingDirectory: URL) throws {
        let target = try pluginDirectory(id: id)
        if fileManager.fileExists(atPath: target.path) {
            let backupName = ".backup-\(id)-\(UUID().uuidString)"
            _ = try fileManager.replaceItemAt(
                target,
                withItemAt: stagingDirectory,
                backupItemName: backupName,
                options: []
            )
            let backup = target.deletingLastPathComponent().appendingPathComponent(backupName)
            if fileManager.fileExists(atPath: backup.path) {
                try? fileManager.removeItem(at: backup)
            }
        } else {
            try fileManager.moveItem(at: stagingDirectory, to: target)
        }
    }

    private func loadStates() throws -> [MobilePluginState] {
        let url = try applicationSupportDirectory().appendingPathComponent("MobilePluginStates.json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try decoder.decode([MobilePluginState].self, from: Data(contentsOf: url))
    }

    private func importsDirectory() throws -> URL {
        try ensureDirectory(
            try applicationSupportDirectory().appendingPathComponent(
                "MobilePluginImports",
                isDirectory: true
            )
        )
    }

    private func dataDirectory(pluginID: String) throws -> URL {
        guard pluginID == pluginID.lowercased(),
              pluginID.range(
                  of: "^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$",
                  options: .regularExpression
              ) != nil else {
            throw MobilePluginError.invalidPluginID
        }
        let root = try ensureDirectory(
            try applicationSupportDirectory().appendingPathComponent(
                "MobilePluginData",
                isDirectory: true
            )
        )
        return try ensureDirectory(root.appendingPathComponent(pluginID, isDirectory: true))
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

    private func saveJSON<T: Encodable>(_ value: T, to target: URL) throws {
        let parent = target.deletingLastPathComponent()
        _ = try ensureDirectory(parent)
        let temporary = parent.appendingPathComponent(".\(target.lastPathComponent).\(UUID().uuidString).tmp")
        try encoder.encode(value).write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: target)
        }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }
}
