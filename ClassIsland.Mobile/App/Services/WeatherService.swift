import Foundation

struct WeatherCity: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let affiliation: String
    let latitude: Double
    let longitude: Double
    let timeZoneOffsetSeconds: Int

    var displayName: String {
        var affiliationParts = affiliation
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if affiliationParts.first?.caseInsensitiveCompare(name) == .orderedSame {
            affiliationParts.removeFirst()
        }
        guard !affiliationParts.isEmpty else {
            return name
        }
        return "\(name) (\(affiliationParts.joined(separator: ", ")))"
    }
}

struct WeatherCurrent: Codable, Equatable, Sendable {
    let weatherCode: String
    let temperature: String
    let feelsLike: String
    let humidity: String
    let pressure: String
    let windSpeed: String
    let windDirectionDegrees: Double?
}

struct WeatherDailyForecast: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let highTemperature: String
    let lowTemperature: String
    let daytimeWeatherCode: String
    let nighttimeWeatherCode: String

    var id: Date { date }

    var conditionTitle: String {
        presentation.conditionTitle
    }

    var symbolName: String {
        presentation.symbolName(for: .condition)
    }

    private var presentation: WeatherPresentation {
        WeatherPresentation(
            weatherCode: daytimeWeatherCode,
            temperature: highTemperature,
            humidity: "",
            windSpeed: "",
            airQualityIndex: "",
            pressure: "",
            feelsLike: ""
        )
    }
}

struct WeatherAlert: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let type: String
    let level: String
    let detail: String
    let publishedAt: Date?
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    let city: WeatherCity
    let current: WeatherCurrent
    let airQualityIndex: String
    let dailyForecast: [WeatherDailyForecast]
    let alerts: [WeatherAlert]
    let updatedAt: Date
    let fetchedAt: Date

    var presentation: WeatherPresentation {
        WeatherPresentation(
            weatherCode: current.weatherCode,
            temperature: current.temperature,
            humidity: current.humidity,
            windSpeed: current.windSpeed,
            airQualityIndex: airQualityIndex,
            pressure: current.pressure,
            feelsLike: current.feelsLike
        )
    }
}

actor WeatherService {
    private static let host = "weatherapi.market.xiaomi.com"
    private static let appKey = "weather20151024"
    private static let signature = "zUFJoAR2ZVrDy1vF3D07"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchCities(matching query: String) async throws -> [WeatherCity] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmedQuery.isEmpty
            ? "/wtr-v3/location/city/hots"
            : "/wtr-v3/location/city/search"
        var queryItems = [URLQueryItem(name: "locale", value: "zh_cn")]
        if !trimmedQuery.isEmpty {
            queryItems.insert(URLQueryItem(name: "name", value: trimmedQuery), at: 0)
        }
        let data = try await request(path: path, queryItems: queryItems)
        return try Self.decodeCities(from: data)
    }

    func fetchWeather(cityID: String, fetchedAt: Date = Date()) async throws -> WeatherSnapshot {
        let city = try await resolveCity(id: cityID)
        return try await fetchWeather(for: city, fetchedAt: fetchedAt)
    }

    func fetchWeather(for city: WeatherCity, fetchedAt: Date = Date()) async throws -> WeatherSnapshot {
        let data = try await request(
            path: "/wtr-v3/weather/all",
            queryItems: [
                URLQueryItem(name: "latitude", value: Self.coordinate(city.latitude)),
                URLQueryItem(name: "longitude", value: Self.coordinate(city.longitude)),
                URLQueryItem(name: "locationKey", value: city.id),
                URLQueryItem(name: "days", value: "15"),
                URLQueryItem(name: "appKey", value: Self.appKey),
                URLQueryItem(name: "sign", value: Self.signature),
                URLQueryItem(name: "isGlobal", value: "false"),
                URLQueryItem(name: "locale", value: "zh_cn")
            ]
        )
        return try Self.decodeWeather(from: data, city: city, fetchedAt: fetchedAt)
    }

    static func decodeCities(from data: Data) throws -> [WeatherCity] {
        let rawCities = try JSONDecoder().decode([XiaomiCity].self, from: data)
        var knownIDs = Set<String>()
        return rawCities.compactMap { raw in
            let id = (raw.locationKey ?? raw.key ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty,
                  (raw.status ?? 0) == 0,
                  let latitude = Double(raw.latitude),
                  let longitude = Double(raw.longitude),
                  knownIDs.insert(id).inserted else {
                return nil
            }
            return WeatherCity(
                id: id,
                name: raw.name.trimmingCharacters(in: .whitespacesAndNewlines),
                affiliation: raw.affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: latitude,
                longitude: longitude,
                timeZoneOffsetSeconds: raw.timeZoneShift ?? 0
            )
        }
    }

    static func decodeWeather(
        from data: Data,
        city: WeatherCity,
        fetchedAt: Date = Date()
    ) throws -> WeatherSnapshot {
        let raw = try JSONDecoder().decode(XiaomiWeatherResponse.self, from: data)
        let updatedAt = raw.updateTime.map {
            Date(timeIntervalSince1970: TimeInterval($0) / 1_000)
        } ?? parseDate(raw.current.pubTime) ?? fetchedAt
        let unit = raw.forecastDaily?.temperature?.unit ?? raw.current.temperature.unit

        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(secondsFromGMT: city.timeZoneOffsetSeconds) {
            calendar.timeZone = timeZone
        }
        let startOfDay = calendar.startOfDay(for: updatedAt)
        let temperatures = raw.forecastDaily?.temperature?.value ?? []
        let weatherRanges = raw.forecastDaily?.weather?.value ?? []
        let dailyCount = min(min(temperatures.count, weatherRanges.count), 5)
        let dailyForecast = (0..<dailyCount).compactMap { index -> WeatherDailyForecast? in
            guard let date = calendar.date(byAdding: .day, value: index, to: startOfDay) else {
                return nil
            }
            return WeatherDailyForecast(
                date: date,
                highTemperature: formatted(temperatures[index].from, unit: unit),
                lowTemperature: formatted(temperatures[index].to, unit: unit),
                daytimeWeatherCode: weatherRanges[index].from,
                nighttimeWeatherCode: weatherRanges[index].to
            )
        }

        var alertTypes = Set<String>()
        let alerts = (raw.alerts ?? [])
            .map { alert in
                WeatherAlert(
                    id: clipped(
                        alert.alertID ?? "\(alert.title)-\(alert.pubTime ?? "")",
                        limit: 120
                    ),
                    title: clipped(alert.title, limit: 80),
                    type: clipped(alert.type ?? "", limit: 24),
                    level: clipped(alert.level ?? "", limit: 16),
                    detail: clipped(alert.detail ?? "", limit: 800),
                    publishedAt: parseDate(alert.pubTime)
                )
            }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .filter { alert in
                let deduplicationKey = alert.type.isEmpty ? alert.title : alert.type
                return alertTypes.insert(deduplicationKey).inserted
            }
            .prefix(8)

        let current = WeatherCurrent(
            weatherCode: clipped(raw.current.weather, limit: 4),
            temperature: formatted(raw.current.temperature.value, unit: raw.current.temperature.unit),
            feelsLike: formatted(raw.current.feelsLike.value, unit: raw.current.feelsLike.unit),
            humidity: formatted(raw.current.humidity.value, unit: raw.current.humidity.unit),
            pressure: formatted(raw.current.pressure.value, unit: raw.current.pressure.unit),
            windSpeed: formatted(raw.current.wind.speed.value, unit: raw.current.wind.speed.unit),
            windDirectionDegrees: Double(raw.current.wind.direction.value)
        )

        return WeatherSnapshot(
            city: city,
            current: current,
            airQualityIndex: clipped(raw.airQuality?.aqi ?? "--", limit: 8),
            dailyForecast: dailyForecast,
            alerts: Array(alerts),
            updatedAt: updatedAt,
            fetchedAt: fetchedAt
        )
    }

    private func resolveCity(id: String) async throws -> WeatherCity {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { throw WeatherServiceError.cityNotFound }
        let data = try await request(
            path: "/wtr-v3/location/city/info",
            queryItems: [
                URLQueryItem(name: "locationKey", value: normalizedID),
                URLQueryItem(name: "locale", value: "zh_cn")
            ]
        )
        guard let city = try Self.decodeCities(from: data).first(where: { $0.id == normalizedID }) else {
            throw WeatherServiceError.cityNotFound
        }
        return city
    }

    private func request(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("ClassIsland-iOS/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw WeatherServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WeatherServiceError.httpStatus(response.statusCode)
        }
        return data
    }

    private static func coordinate(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func formatted(_ value: String, unit: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return "--" }
        guard !trimmedUnit.isEmpty else { return clipped(trimmedValue, limit: 12) }
        let separator = ["℃", "%", "°"].contains(trimmedUnit) ? "" : " "
        return clipped("\(trimmedValue)\(separator)\(trimmedUnit)", limit: 16)
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}

enum WeatherServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "天气请求地址无效。"
        case .invalidResponse:
            "天气服务返回了无法识别的响应。"
        case .httpStatus(let status):
            "天气服务请求失败（HTTP \(status)）。"
        case .cityNotFound:
            "天气服务中未找到所选城市。"
        }
    }
}

private struct XiaomiCity: Decodable {
    let affiliation: String
    let key: String?
    let latitude: String
    let locationKey: String?
    let longitude: String
    let name: String
    let status: Int?
    let timeZoneShift: Int?
}

private struct XiaomiWeatherResponse: Decodable {
    let current: XiaomiCurrentWeather
    let forecastDaily: XiaomiDailyForecast?
    let alerts: [XiaomiAlert]?
    let updateTime: Int64?
    let airQuality: XiaomiAirQuality?

    private enum CodingKeys: String, CodingKey {
        case current
        case forecastDaily
        case alerts
        case updateTime
        case airQuality = "aqi"
    }
}

private struct XiaomiCurrentWeather: Decodable {
    let feelsLike: XiaomiMeasuredValue
    let humidity: XiaomiMeasuredValue
    let pressure: XiaomiMeasuredValue
    let pubTime: String?
    let temperature: XiaomiMeasuredValue
    let weather: String
    let wind: XiaomiWind
}

private struct XiaomiMeasuredValue: Decodable {
    let unit: String
    let value: String
}

private struct XiaomiWind: Decodable {
    let direction: XiaomiMeasuredValue
    let speed: XiaomiMeasuredValue
}

private struct XiaomiDailyForecast: Decodable {
    let temperature: XiaomiDailyRangeGroup?
    let weather: XiaomiDailyWeatherGroup?
}

private struct XiaomiDailyRangeGroup: Decodable {
    let unit: String
    let value: [XiaomiStringRange]
}

private struct XiaomiDailyWeatherGroup: Decodable {
    let value: [XiaomiStringRange]
}

private struct XiaomiStringRange: Decodable {
    let from: String
    let to: String
}

private struct XiaomiAlert: Decodable {
    let alertID: String?
    let pubTime: String?
    let title: String
    let type: String?
    let level: String?
    let detail: String?

    private enum CodingKeys: String, CodingKey {
        case alertID = "alertId"
        case pubTime
        case title
        case type
        case level
        case detail
    }
}

private struct XiaomiAirQuality: Decodable {
    let aqi: String
}
