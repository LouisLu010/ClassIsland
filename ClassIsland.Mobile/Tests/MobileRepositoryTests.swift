import XCTest
@testable import ClassIslandMobile

final class MobileRepositoryTests: XCTestCase {
    func testMigratesLegacyUserFilesToDocumentsDirectory() throws {
        let directories = makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }

        let profileData = Data("legacy-profile".utf8)
        var settings = MobileSettings()
        settings.showTeacher = false
        settings.timeOffsetSeconds = 42

        let legacyRepository = MobileRepository(rootDirectory: directories.applicationSupport)
        try legacyRepository.saveProfileData(profileData)
        try legacyRepository.saveSettings(settings)

        let repository = MobileRepository(
            rootDirectory: directories.applicationSupport,
            documentsDirectory: directories.documents
        )

        XCTAssertEqual(try repository.loadProfileData(), profileData)
        XCTAssertEqual(try repository.loadSettings(), settings)
        XCTAssertTrue(fileExists("Profile.json", in: directories.documents))
        XCTAssertTrue(fileExists("MobileSettings.json", in: directories.documents))
        XCTAssertFalse(fileExists("Profile.json", in: directories.applicationSupport))
        XCTAssertFalse(fileExists("MobileSettings.json", in: directories.applicationSupport))
    }

    func testExistingDocumentsFileTakesPrecedenceOverLegacyFile() throws {
        let directories = makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }

        let legacyData = Data("legacy-profile".utf8)
        let documentData = Data("document-profile".utf8)
        try MobileRepository(rootDirectory: directories.applicationSupport)
            .saveProfileData(legacyData)
        try MobileRepository(rootDirectory: directories.documents)
            .saveProfileData(documentData)

        let repository = MobileRepository(
            rootDirectory: directories.applicationSupport,
            documentsDirectory: directories.documents
        )

        XCTAssertEqual(try repository.loadProfileData(), documentData)
        XCTAssertEqual(
            try Data(contentsOf: directories.applicationSupport.appendingPathComponent("Profile.json")),
            legacyData
        )
    }

    func testKeepsRuntimeCacheInApplicationSupport() throws {
        let directories = makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }

        let repository = MobileRepository(
            rootDirectory: directories.applicationSupport,
            documentsDirectory: directories.documents
        )
        try repository.saveProfileData(Data("profile".utf8))
        try repository.saveWeather(makeWeatherSnapshot())

        XCTAssertTrue(fileExists("Profile.json", in: directories.documents))
        XCTAssertFalse(fileExists("Profile.json", in: directories.applicationSupport))
        XCTAssertTrue(fileExists("WeatherCache.json", in: directories.applicationSupport))
        XCTAssertFalse(fileExists("WeatherCache.json", in: directories.documents))
    }

    func testRemoveProfileDeletesDocumentsFile() throws {
        let directories = makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }

        let repository = MobileRepository(
            rootDirectory: directories.applicationSupport,
            documentsDirectory: directories.documents
        )
        try repository.saveProfileData(Data("profile".utf8))

        try repository.removeProfile()

        XCTAssertFalse(fileExists("Profile.json", in: directories.documents))
    }

    private func makeDirectories() -> (
        root: URL,
        applicationSupport: URL,
        documents: URL
    ) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ClassIslandRepositoryTests-\(UUID().uuidString)",
            isDirectory: true
        )
        return (
            root,
            root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            root.appendingPathComponent("Documents", isDirectory: true)
        )
    }

    private func fileExists(_ fileName: String, in directory: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(fileName).path
        )
    }

    private func makeWeatherSnapshot() -> WeatherSnapshot {
        WeatherSnapshot(
            city: WeatherCity(
                id: "weathercn:101010100",
                name: "北京市",
                affiliation: "中国",
                latitude: 39.904,
                longitude: 116.408,
                timeZoneOffsetSeconds: 28_800
            ),
            current: WeatherCurrent(
                weatherCode: "0",
                temperature: "26℃",
                feelsLike: "27℃",
                humidity: "50%",
                pressure: "1012 hPa",
                windSpeed: "5 km/h",
                windDirectionDegrees: 90
            ),
            airQualityIndex: "32",
            dailyForecast: [],
            alerts: [],
            updatedAt: Date(timeIntervalSince1970: 1_783_735_000),
            fetchedAt: Date(timeIntervalSince1970: 1_783_735_000)
        )
    }
}
