import XCTest
import ZIPFoundation
@testable import ClassIslandMobile

final class MobilePluginTests: XCTestCase {
    func testArchivePathValidationRejectsTraversalAndWindowsPaths() throws {
        for path in ["../secret", "mobile/../secret", "/absolute", "C:/absolute", "mobile\\entry.json"] {
            XCTAssertThrowsError(try MobilePluginPackageService.validateArchivePath(path), path)
        }

        XCTAssertEqual(
            try MobilePluginPackageService.validateArchivePath("mobile/assets/icon.png"),
            "mobile/assets/icon.png"
        )
    }

    func testActivityPresentationUsesBoundedUTF8Payload() throws {
        let presentation = PluginActivityPresentation(
            title: String(repeating: "标题", count: 40),
            value: String(repeating: "内容", count: 80),
            systemImage: "sparkles"
        )
        let data = try JSONEncoder().encode(presentation)
        let decoded = try JSONDecoder().decode(PluginActivityPresentation.self, from: data)

        XCTAssertLessThanOrEqual(presentation.title.utf8.count, 24)
        XCTAssertLessThanOrEqual(presentation.value.utf8.count, 48)
        XCTAssertEqual(decoded, presentation)
        XCTAssertLessThan(data.count, 128)
    }

    func testStageImportRejectsOversizedPackageWithoutKeepingCopy() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Oversized.cipx")
        try Data(count: MobilePluginPackageService.maximumPackageSize + 1).write(to: source)
        let repository = MobilePluginRepository(rootDirectory: root.appendingPathComponent("AppData"))

        XCTAssertThrowsError(try repository.stageImportedPackage(from: source)) { error in
            guard case MobilePluginError.packageTooLarge = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let imports = root.appendingPathComponent("AppData/MobilePluginImports")
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: imports.path),
            []
        )
    }

    func testScheduleEventRequiresScheduleReadCapability() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("InvalidEvent.cipx")
        let manifest = Data(
            """
            id: classisland.mobile.invalid-event
            name: Invalid Event
            icon: ""
            version: 1.0.0
            mobile:
              apiVersion: 1
              runtime: declarative
              entry: mobile/plugin.json
              capabilities: []
            """.utf8
        )
        let definition = Data(
            """
            {
              "schemaVersion": 1,
              "events": [{
                "event": "schedule.classStarted",
                "actions": [{ "kind": "components.refresh" }]
              }]
            }
            """.utf8
        )
        try writePackage(at: packageURL, manifest: manifest, definition: definition)

        XCTAssertThrowsError(try MobilePluginPackageService().inspectPackage(at: packageURL)) { error in
            XCTAssertTrue(error.localizedDescription.contains("schedule.read"))
        }
    }

    func testPackageRejectsSymbolicLinks() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("Symlink.cipx")
        try makePackage(at: packageURL)
        let linkTarget = Data("../outside".utf8)
        do {
            let archive = try Archive(url: packageURL, accessMode: .update)
            try archive.addEntry(
                with: "mobile/link",
                type: .symlink,
                uncompressedSize: Int64(linkTarget.count)
            ) { position, size in
                let lower = Int(position)
                let upper = min(lower + size, linkTarget.count)
                return linkTarget.subdata(in: lower..<upper)
            }
        }

        XCTAssertThrowsError(try MobilePluginPackageService().inspectPackage(at: packageURL)) { error in
            guard case MobilePluginError.symbolicLink("mobile/link") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPackageInspectionAndInstallOnlyExtractMobilePayload() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("Example.cipx")
        try makePackage(at: packageURL)

        let service = MobilePluginPackageService()
        let repository = MobilePluginRepository(rootDirectory: root.appendingPathComponent("AppData"))
        let installation = try service.inspectPackage(at: packageURL)

        XCTAssertEqual(installation.id, "classisland.mobile.tests")
        XCTAssertEqual(installation.manifest.mobile.apiVersion, 1)
        XCTAssertEqual(installation.definition.components.first?.id, "current")
        XCTAssertEqual(installation.packageSHA256.count, 64)

        try service.installPackage(
            at: packageURL,
            installation: installation,
            state: installedState(for: installation),
            repository: repository
        )
        let installedDirectory = try repository.pluginDirectory(id: installation.id)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: installedDirectory.appendingPathComponent("mobile/plugin.json").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: installedDirectory.appendingPathComponent("DesktopPlugin.dll").path
            )
        )
        XCTAssertEqual(
            try repository.loadInstalledPlugins().first?.state,
            installedState(for: installation)
        )
    }

    func testPluginSettingsSurvivePackageReplacementAndRemoval() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("Example.cipx")
        try makePackage(at: packageURL)

        let repository = MobilePluginRepository(rootDirectory: root.appendingPathComponent("AppData"))
        let service = MobilePluginPackageService()
        let installation = try service.inspectPackage(at: packageURL)
        try service.installPackage(
            at: packageURL,
            installation: installation,
            state: installedState(for: installation),
            repository: repository
        )
        try repository.saveSettings(["label": .string("保留值")], pluginID: installation.id)

        try service.installPackage(
            at: packageURL,
            installation: installation,
            state: installedState(for: installation),
            repository: repository
        )
        XCTAssertEqual(
            try repository.loadSettings(pluginID: installation.id)["label"],
            .string("保留值")
        )

        try repository.removePlugin(id: installation.id, removeData: false)
        XCTAssertEqual(
            try repository.loadSettings(pluginID: installation.id)["label"],
            .string("保留值")
        )
    }

    func testRuntimeRequiresCapabilityBeforeResolvingScheduleTokens() throws {
        let schedule = scheduleSnapshot()
        let current = try XCTUnwrap(schedule.current)
        let context = MobilePluginRuntimeContext(now: current.start, schedule: schedule, weather: nil)
        let runtime = MobilePluginRuntime()
        var plugin = installedPlugin(grantedCapabilities: [])

        XCTAssertEqual(
            runtime.renderComponents(plugins: [plugin], settings: [:], context: context).first?.value,
            ""
        )

        plugin.state.grantedCapabilities.insert(.scheduleRead)
        XCTAssertEqual(
            runtime.renderComponents(plugins: [plugin], settings: [:], context: context).first?.value,
            "数学"
        )
        XCTAssertEqual(
            runtime.activityPresentation(plugins: [plugin], settings: [:], context: context),
            nil
        )

        plugin.state.grantedCapabilities.insert(.liveActivityRender)
        XCTAssertEqual(
            runtime.activityPresentation(plugins: [plugin], settings: [:], context: context)?.value,
            "数学"
        )
    }

    func testScheduleCheckpointPersistsAcrossColdLaunch() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = MobileRepository(rootDirectory: root)
        let checkpoint = MobilePluginScheduleCheckpoint(snapshot: scheduleSnapshot())

        try repository.savePluginScheduleCheckpoint(checkpoint)

        XCTAssertEqual(try repository.loadPluginScheduleCheckpoint(), checkpoint)
        try repository.savePluginScheduleCheckpoint(nil)
        XCTAssertNil(try repository.loadPluginScheduleCheckpoint())
    }

    @MainActor
    func testPluginUpdateDoesNotRegrantRevokedCapabilities() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("Example.cipx")
        try makePackage(at: packageURL)
        let repository = MobilePluginRepository(rootDirectory: root.appendingPathComponent("AppData"))
        let manager = MobilePluginManager(repository: repository)

        await manager.prepareInstallation(from: packageURL)
        await manager.installPending(grantedCapabilities: [.scheduleRead])
        await manager.setCapability(
            .scheduleRead,
            granted: false,
            pluginID: "classisland.mobile.tests"
        )
        await manager.prepareInstallation(from: packageURL)

        XCTAssertTrue(manager.pendingInstall?.isUpdate == true)
        XCTAssertEqual(
            manager.pendingInstall?.initialGrantedCapabilities ?? [],
            Set<MobilePluginCapability>()
        )
        manager.cancelPendingInstallation()
    }

    @MainActor
    func testManagerRestoresRetainedSettingsAfterReinstall() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("Example.cipx")
        try makePackage(at: packageURL)
        let repository = MobilePluginRepository(rootDirectory: root.appendingPathComponent("AppData"))
        let manager = MobilePluginManager(repository: repository)

        await manager.prepareInstallation(from: packageURL)
        await manager.installPending(grantedCapabilities: [])
        manager.setSettingValue(
            .string("保留值"),
            pluginID: "classisland.mobile.tests",
            key: "label"
        )
        await manager.uninstall(pluginID: "classisland.mobile.tests")
        await manager.prepareInstallation(from: packageURL)
        await manager.installPending(grantedCapabilities: [])

        XCTAssertEqual(
            manager.settingValue(pluginID: "classisland.mobile.tests", key: "label"),
            .string("保留值")
        )
    }

    private func makePackage(at url: URL) throws {
        let manifest = Data(
            """
            id: classisland.mobile.tests
            name: Mobile Tests
            description: Test package
            entranceAssembly: DesktopPlugin.dll
            icon: ""
            apiVersion: 2.0.0.0
            version: 1.0.0
            author: ClassIsland
            mobile:
              apiVersion: 1
              runtime: declarative
              entry: mobile/plugin.json
              capabilities:
                - schedule.read
                - liveActivity.render
            """.utf8
        )
        let definition = Data(
            """
            {
              "schemaVersion": 1,
              "settings": [{
                "key": "label",
                "title": "Label",
                "type": "text",
                "defaultValue": "Default"
              }],
              "components": [
                {
                  "id": "current",
                  "kind": "metric",
                  "title": "Current",
                  "value": "{{schedule.current.subject}}"
                }
              ],
              "events": [],
              "allowedDomains": [],
              "liveActivity": {
                "title": "Current",
                "value": "{{schedule.current.subject}}"
              }
            }
            """.utf8
        )

        try writePackage(at: url, manifest: manifest, definition: definition)
    }

    private func writePackage(at url: URL, manifest: Data, definition: Data) throws {
        let archive = try Archive(url: url, accessMode: .create)
        try add(manifest, path: "manifest.yml", to: archive)
        try add(definition, path: "mobile/plugin.json", to: archive)
        try add(Data("desktop".utf8), path: "DesktopPlugin.dll", to: archive)
    }

    private func add(_ data: Data, path: String, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            let lower = Int(position)
            let upper = min(lower + size, data.count)
            return data.subdata(in: lower..<upper)
        }
    }

    private func installedPlugin(
        grantedCapabilities: Set<MobilePluginCapability>
    ) -> InstalledMobilePlugin {
        let component = MobilePluginComponentDefinition(
            id: "current",
            kind: .metric,
            title: "Current",
            value: "{{schedule.current.subject}}"
        )
        let definition = MobilePluginDefinition(
            schemaVersion: 1,
            components: [component],
            liveActivity: MobilePluginLiveActivityDefinition(
                title: "Current",
                value: "{{schedule.current.subject}}"
            )
        )
        let manifest = MobilePluginPackageManifest(
            id: "classisland.mobile.tests",
            name: "Mobile Tests",
            version: "1.0.0",
            mobile: MobilePluginPlatformManifest(
                apiVersion: 1,
                runtime: "declarative",
                entry: "mobile/plugin.json",
                capabilities: [.scheduleRead, .liveActivityRender]
            )
        )
        return InstalledMobilePlugin(
            installation: MobilePluginInstallation(
                manifest: manifest,
                definition: definition,
                packageSHA256: String(repeating: "0", count: 64),
                installedAt: Date(),
                iconRelativePath: nil
            ),
            state: MobilePluginState(
                id: manifest.id,
                isEnabled: true,
                grantedCapabilities: grantedCapabilities
            )
        )
    }

    private func installedState(
        for installation: MobilePluginInstallation
    ) -> MobilePluginState {
        MobilePluginState(
            id: installation.id,
            isEnabled: true,
            grantedCapabilities: Set(installation.manifest.mobile.capabilities)
        )
    }

    private func scheduleSnapshot() -> ScheduleSnapshot {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let current = ScheduleSession(
            id: "current",
            index: 0,
            start: start,
            end: start.addingTimeInterval(2_700),
            subject: "数学",
            initial: "数",
            teacher: "周老师",
            isOutdoor: false
        )
        return ScheduleSnapshot(
            date: start,
            profileName: "测试课表",
            planName: "星期一",
            phase: .inClass,
            sessions: [current],
            breaks: [],
            current: current,
            currentBreak: nil,
            next: nil,
            timeOffsetSeconds: 0
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
