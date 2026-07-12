import Foundation

enum WeatherMetric: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case condition
    case humidity
    case wind
    case airQuality
    case pressure
    case feelsLike

    var id: Self { self }

    var title: String {
        switch self {
        case .condition: "天气与气温"
        case .humidity: "湿度"
        case .wind: "风速"
        case .airQuality: "空气质量"
        case .pressure: "气压"
        case .feelsLike: "体感温度"
        }
    }

    var shortTitle: String {
        switch self {
        case .condition: "天"
        case .humidity: "湿"
        case .wind: "风"
        case .airQuality: "气"
        case .pressure: "压"
        case .feelsLike: "感"
        }
    }

    var systemImage: String {
        switch self {
        case .condition: "cloud.sun.fill"
        case .humidity: "humidity.fill"
        case .wind: "wind"
        case .airQuality: "aqi.medium"
        case .pressure: "gauge.with.needle"
        case .feelsLike: "thermometer.medium"
        }
    }
}

struct WeatherPresentation: Codable, Equatable, Hashable, Sendable {
    let weatherCode: String
    let temperature: String
    let humidity: String
    let windSpeed: String
    let airQualityIndex: String
    let pressure: String
    let feelsLike: String

    init(
        weatherCode: String,
        temperature: String,
        humidity: String,
        windSpeed: String,
        airQualityIndex: String,
        pressure: String,
        feelsLike: String
    ) {
        self.weatherCode = Self.clipped(weatherCode, limit: 4)
        self.temperature = Self.clipped(temperature, limit: 10)
        self.humidity = Self.clipped(humidity, limit: 10)
        self.windSpeed = Self.clipped(windSpeed, limit: 14)
        self.airQualityIndex = Self.clipped(airQualityIndex, limit: 8)
        self.pressure = Self.clipped(pressure, limit: 14)
        self.feelsLike = Self.clipped(feelsLike, limit: 10)
    }

    var conditionTitle: String {
        switch weatherCode {
        case "0": "晴"
        case "1": "多云"
        case "2": "阴"
        case "3": "阵雨"
        case "4": "雷阵雨"
        case "5": "雷阵雨伴冰雹"
        case "6": "雨夹雪"
        case "7": "小雨"
        case "8": "中雨"
        case "9": "大雨"
        case "10": "暴雨"
        case "11": "大暴雨"
        case "12": "特大暴雨"
        case "13": "阵雪"
        case "14": "小雪"
        case "15": "中雪"
        case "16": "大雪"
        case "17": "暴雪"
        case "18": "雾"
        case "19": "冻雨"
        case "20": "沙尘暴"
        case "21": "小到中雨"
        case "22": "中到大雨"
        case "23": "大到暴雨"
        case "24": "暴雨到大暴雨"
        case "25": "大暴雨到特大暴雨"
        case "26": "小到中雪"
        case "27": "中到大雪"
        case "28": "大到暴雪"
        case "29": "浮尘"
        case "30": "扬沙"
        case "31": "强沙尘暴"
        case "32": "飑"
        case "33": "龙卷风"
        case "34": "弱高吹雪"
        case "35": "轻雾"
        case "53": "霾"
        case "301": "雨"
        case "302": "雪"
        default: "未知"
        }
    }

    func symbolName(for metric: WeatherMetric) -> String {
        guard metric == .condition else { return metric.systemImage }
        return switch weatherCode {
        case "0": "sun.max.fill"
        case "1": "cloud.sun.fill"
        case "2": "cloud.fill"
        case "4", "5": "cloud.bolt.rain.fill"
        case "6", "19": "cloud.sleet.fill"
        case "10", "11", "12", "23", "24", "25": "cloud.heavyrain.fill"
        case "13", "14", "15", "16", "17", "26", "27", "28", "34", "302": "cloud.snow.fill"
        case "18", "35": "cloud.fog.fill"
        case "20", "29", "30", "31", "53": "sun.haze.fill"
        case "32": "wind"
        case "33": "tornado"
        case "3", "7", "8", "9", "21", "22", "301": "cloud.rain.fill"
        default: "questionmark.circle.fill"
        }
    }

    func value(for metric: WeatherMetric) -> String {
        switch metric {
        case .condition: "\(conditionTitle) \(temperature)"
        case .humidity: "湿度 \(humidity)"
        case .wind: "风速 \(windSpeed)"
        case .airQuality: "AQI \(airQualityIndex)"
        case .pressure: "气压 \(pressure)"
        case .feelsLike: "体感 \(feelsLike)"
        }
    }

    func compactValue(for metric: WeatherMetric) -> String {
        switch metric {
        case .condition:
            "\(String(conditionTitle.prefix(2))) \(compactTemperature(temperature))"
        case .humidity:
            humidity.replacingOccurrences(of: " ", with: "")
        case .wind:
            windSpeed.replacingOccurrences(of: " ", with: "")
        case .airQuality:
            "AQI \(airQualityIndex)"
        case .pressure:
            pressure.replacingOccurrences(of: " ", with: "")
        case .feelsLike:
            "体感\(compactTemperature(feelsLike))"
        }
    }

    private func compactTemperature(_ value: String) -> String {
        value
            .replacingOccurrences(of: "℃", with: "°")
            .replacingOccurrences(of: "°C", with: "°")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }
}
