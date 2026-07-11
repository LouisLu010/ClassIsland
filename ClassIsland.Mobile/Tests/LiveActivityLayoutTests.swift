import XCTest
@testable import ClassIslandMobile

final class LiveActivityLayoutTests: XCTestCase {
    func testDefaultLayoutRoundTripsThroughSettings() throws {
        var settings = MobileSettings()
        settings.liveActivityLayout = .default

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MobileSettings.self, from: data)

        XCTAssertEqual(decoded.liveActivityLayout, .default)
        XCTAssertEqual(decoded.liveActivityLayout.components(in: .compactLeading).count, 1)
        XCTAssertEqual(decoded.liveActivityLayout.components(in: .lockPrimary).count, 2)
        XCTAssertTrue(
            decoded.liveActivityLayout.components(in: .lockHeader).contains { $0.kind == .weather }
        )
    }

    func testOlderSettingsReceiveDefaultLayout() throws {
        let decoded = try JSONDecoder().decode(MobileSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(decoded.liveActivityLayout, .default)
        XCTAssertEqual(decoded.timeOffsetSeconds, 0)
    }

    func testLegacyVerboseComponentEncodingMigrates() throws {
        let json = """
        {
          "regions": {
            "compactLeading": [{
              "id": "00000000-0000-0000-0000-000000000001",
              "kind": "date",
              "customText": "",
              "isEmphasized": true,
              "showsIcon": false
            }]
          }
        }
        """

        let layout = try JSONDecoder().decode(LiveActivityLayout.self, from: Data(json.utf8))
        let component = try XCTUnwrap(layout.components(in: .compactLeading).first)

        XCTAssertEqual(component.kind, .date)
        XCTAssertTrue(component.isEmphasized)
        XCTAssertFalse(component.showsIcon)
        XCTAssertFalse(component.clockShowsSeconds)
        XCTAssertFalse(component.clockUsesSystemTime)
        XCTAssertEqual(component.weatherMetric, .condition)
    }

    func testCompactRegionReplacesExistingComponent() {
        var layout = LiveActivityLayout.default
        let replacement = LiveActivityComponentConfiguration(kind: .date)

        layout.add(replacement, to: .compactLeading)

        XCTAssertEqual(layout.components(in: .compactLeading), [replacement])
    }

    func testClockComponentOptionsRoundTrip() throws {
        let component = LiveActivityComponentConfiguration(
            kind: .clock,
            isEmphasized: true,
            showsIcon: false,
            clockShowsSeconds: true,
            clockUsesSystemTime: true
        )

        let decoded = try JSONDecoder().decode(
            LiveActivityComponentConfiguration.self,
            from: JSONEncoder().encode(component)
        )

        XCTAssertEqual(decoded, component)
        XCTAssertTrue(decoded.clockShowsSeconds)
        XCTAssertTrue(decoded.clockUsesSystemTime)
    }

    func testWeatherComponentMetricRoundTrips() throws {
        let component = LiveActivityComponentConfiguration(
            kind: .weather,
            isEmphasized: true,
            weatherMetric: .airQuality
        )

        let decoded = try JSONDecoder().decode(
            LiveActivityComponentConfiguration.self,
            from: JSONEncoder().encode(component)
        )

        XCTAssertEqual(decoded, component)
        XCTAssertEqual(decoded.weatherMetric, .airQuality)
    }

    func testExpandedRegionSupportsReorderingAndCapacityLimit() {
        var layout = LiveActivityLayout.default
        layout.setComponents([], in: .expandedBottom)
        let components = LiveActivityComponentKind.allCases.prefix(5).map {
            LiveActivityComponentConfiguration(kind: $0)
        }
        for component in components {
            layout.add(component, to: .expandedBottom)
        }

        XCTAssertEqual(layout.components(in: .expandedBottom).count, 4)
        let originalFirst = layout.components(in: .expandedBottom)[0]
        layout.move(from: IndexSet(integer: 0), to: 4, in: .expandedBottom)
        XCTAssertEqual(layout.components(in: .expandedBottom).last, originalFirst)
    }

    func testEmptyRegionAndRuntimeComponentIdentityRoundTrip() throws {
        var layout = LiveActivityLayout.default
        layout.setComponents([], in: .compactLeading)

        let decoded = try JSONDecoder().decode(
            LiveActivityLayout.self,
            from: JSONEncoder().encode(layout)
        )

        XCTAssertTrue(decoded.components(in: .compactLeading).isEmpty)
        XCTAssertEqual(decoded, layout)
    }

    func testActivityContentStateStaysBelowActivityKitPayloadLimit() throws {
        let state = ScheduleActivityAttributes.ContentState(
            phase: .inClass,
            headline: "数学",
            compactTitle: "数",
            teacher: "周老师",
            timerStart: Date(),
            timerEnd: Date().addingTimeInterval(2_700),
            nextTitle: "英语",
            nextStart: Date().addingTimeInterval(3_000),
            updatedAt: Date(),
            timeOffsetSeconds: 2.5,
            accentRGBA: 0x05ABE8FF,
            layout: .default,
            weather: weatherPresentation
        )

        let data = try JSONEncoder().encode(state)

        XCTAssertLessThan(data.count, 4_096)
    }

    func testMaximumLayoutStaysBelowActivityKitPayloadLimit() throws {
        var layout = LiveActivityLayout.default
        let text = String(
            repeating: "自",
            count: LiveActivityComponentConfiguration.maximumCustomTextLength
        )
        for region in LiveActivityRegion.allCases {
            layout.setComponents(
                (0..<region.maximumComponentCount).map { _ in
                    LiveActivityComponentConfiguration(
                        kind: .customText,
                        customText: text,
                        isEmphasized: true,
                        showsIcon: false
                    )
                },
                in: region
            )
        }
        let longText = String(repeating: "字", count: 48)
        let state = ScheduleActivityAttributes.ContentState(
            phase: .inClass,
            headline: longText,
            compactTitle: "数",
            teacher: longText,
            timerStart: Date(),
            timerEnd: Date().addingTimeInterval(2_700),
            nextTitle: longText,
            nextStart: Date().addingTimeInterval(3_000),
            updatedAt: Date(),
            timeOffsetSeconds: 2.5,
            accentRGBA: 0x05ABE8FF,
            layout: layout,
            weather: weatherPresentation,
            plugin: PluginActivityPresentation(
                title: String(repeating: "标题", count: 24),
                value: String(repeating: "内容", count: 32),
                systemImage: "puzzlepiece.extension"
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let attributes = try encoder.encode(
            ScheduleActivityAttributes(profileName: longText)
        )

        XCTAssertLessThan(data.count + attributes.count, 4_096)
    }

    func testLegacyActivityStateReceivesDefaultLayout() throws {
        let json = """
        {
          "phase": "inClass",
          "headline": "数学",
          "compactTitle": "数",
          "teacher": "",
          "nextTitle": "",
          "updatedAt": 0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(
            ScheduleActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(state.accentRGBA, 0x05ABE8FF)
        XCTAssertEqual(state.layout, .default)
        XCTAssertEqual(state.timeOffsetSeconds, 0)
        XCTAssertNil(state.weather)
        XCTAssertNil(state.plugin)
    }

    private var weatherPresentation: WeatherPresentation {
        WeatherPresentation(
            weatherCode: "0",
            temperature: "27℃",
            humidity: "65%",
            windSpeed: "8 km/h",
            airQualityIndex: "42",
            pressure: "1012 hPa",
            feelsLike: "29℃"
        )
    }
}
