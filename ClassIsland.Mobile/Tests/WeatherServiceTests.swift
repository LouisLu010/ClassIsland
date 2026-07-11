import XCTest
@testable import ClassIslandMobile

final class WeatherServiceTests: XCTestCase {
    func testCitySearchResponseDecodesCoordinatesAndDisplayName() throws {
        let json = """
        [{
          "affiliation": "中国",
          "key": "weathercn:101020100",
          "latitude": "31.23",
          "locationKey": "weathercn:101020100",
          "longitude": "121.474",
          "name": "上海市",
          "status": 0,
          "timeZoneShift": 28800
        }]
        """

        let cities = try WeatherService.decodeCities(from: Data(json.utf8))
        let city = try XCTUnwrap(cities.first)

        XCTAssertEqual(city.id, "weathercn:101020100")
        XCTAssertEqual(city.displayName, "上海市 (中国)")
        XCTAssertEqual(city.latitude, 31.23, accuracy: 0.001)
        XCTAssertEqual(city.longitude, 121.474, accuracy: 0.001)
        XCTAssertEqual(city.timeZoneOffsetSeconds, 28_800)
    }

    func testWeatherResponseBuildsCurrentForecastAndLatestAlerts() throws {
        let city = WeatherCity(
            id: "weathercn:101010100",
            name: "北京市",
            affiliation: "中国",
            latitude: 39.904,
            longitude: 116.408,
            timeZoneOffsetSeconds: 28_800
        )
        let fetchedAt = Date(timeIntervalSince1970: 1_783_735_000)

        let snapshot = try WeatherService.decodeWeather(
            from: Data(weatherFixture.utf8),
            city: city,
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(snapshot.city, city)
        XCTAssertEqual(snapshot.current.weatherCode, "18")
        XCTAssertEqual(snapshot.current.temperature, "27℃")
        XCTAssertEqual(snapshot.current.feelsLike, "31℃")
        XCTAssertEqual(snapshot.current.humidity, "91%")
        XCTAssertEqual(snapshot.current.pressure, "997 hPa")
        XCTAssertEqual(snapshot.current.windSpeed, "2.0 km/h")
        XCTAssertEqual(snapshot.airQualityIndex, "26")
        XCTAssertEqual(snapshot.dailyForecast.count, 3)
        XCTAssertEqual(snapshot.dailyForecast[0].highTemperature, "28℃")
        XCTAssertEqual(snapshot.dailyForecast[0].lowTemperature, "24℃")
        XCTAssertEqual(snapshot.dailyForecast[0].conditionTitle, "中雨")
        XCTAssertEqual(snapshot.alerts.count, 2)
        XCTAssertEqual(snapshot.alerts[0].title, "北京发布暴雨橙色预警")
        XCTAssertEqual(snapshot.presentation.conditionTitle, "雾")
        XCTAssertEqual(snapshot.presentation.symbolName(for: .condition), "cloud.fog.fill")
    }

    func testWeatherCacheRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClassIslandWeatherTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let city = WeatherCity(
            id: "weathercn:101010100",
            name: "北京市",
            affiliation: "中国",
            latitude: 39.904,
            longitude: 116.408,
            timeZoneOffsetSeconds: 28_800
        )
        let snapshot = try WeatherService.decodeWeather(
            from: Data(weatherFixture.utf8),
            city: city,
            fetchedAt: Date(timeIntervalSince1970: 1_783_735_000)
        )
        let repository = MobileRepository(rootDirectory: directory)

        try repository.saveWeather(snapshot)

        XCTAssertEqual(try repository.loadWeather(), snapshot)
    }

    func testWeatherPresentationSupportsEveryMetric() {
        let presentation = WeatherPresentation(
            weatherCode: "0",
            temperature: "27℃",
            humidity: "65%",
            windSpeed: "8 km/h",
            airQualityIndex: "42",
            pressure: "1012 hPa",
            feelsLike: "29℃"
        )

        XCTAssertEqual(presentation.value(for: .condition), "晴 27℃")
        XCTAssertEqual(presentation.value(for: .humidity), "湿度 65%")
        XCTAssertEqual(presentation.compactValue(for: .condition), "晴 27°")
        XCTAssertEqual(presentation.value(for: .airQuality), "AQI 42")
        XCTAssertEqual(presentation.value(for: .pressure), "气压 1012 hPa")
        XCTAssertEqual(presentation.value(for: .feelsLike), "体感 29℃")
    }

    private var weatherFixture: String {
        """
        {
          "current": {
            "feelsLike": { "unit": "℃", "value": "31" },
            "humidity": { "unit": "%", "value": "91" },
            "pressure": { "unit": "hPa", "value": "997" },
            "pubTime": "2026-07-11T09:50:17+08:00",
            "temperature": { "unit": "℃", "value": "27" },
            "weather": "18",
            "wind": {
              "direction": { "unit": "°", "value": "247.0" },
              "speed": { "unit": "km/h", "value": "2.0" }
            }
          },
          "forecastDaily": {
            "temperature": {
              "unit": "℃",
              "value": [
                { "from": "28", "to": "24" },
                { "from": "32", "to": "24" },
                { "from": "29", "to": "23" }
              ]
            },
            "weather": {
              "value": [
                { "from": "8", "to": "10" },
                { "from": "4", "to": "4" },
                { "from": "8", "to": "8" }
              ]
            }
          },
          "alerts": [
            {
              "alertId": "rain-new",
              "pubTime": "2026-07-11T09:30:00+08:00",
              "title": "北京发布暴雨橙色预警",
              "type": "暴雨",
              "level": "橙色",
              "detail": "请注意防范强降雨。"
            },
            {
              "alertId": "rain-old",
              "pubTime": "2026-07-10T09:30:00+08:00",
              "title": "北京发布暴雨黄色预警",
              "type": "暴雨",
              "level": "黄色",
              "detail": "旧预警。"
            },
            {
              "alertId": "thunder",
              "pubTime": "2026-07-11T08:30:00+08:00",
              "title": "北京发布雷电黄色预警",
              "type": "雷电",
              "level": "黄色",
              "detail": "请注意防雷。"
            }
          ],
          "updateTime": 1783734894982,
          "aqi": { "aqi": "26" }
        }
        """
    }
}
