import Foundation

enum ClassIslandDateParser {
    static func secondsSinceMidnight(_ value: String) -> TimeInterval? {
        let timePart: Substring
        if let separator = value.lastIndex(of: "T") {
            timePart = value[value.index(after: separator)...].prefix(8)
        } else if let separator = value.lastIndex(of: " ") {
            timePart = value[value.index(after: separator)...].prefix(8)
        } else {
            timePart = value.prefix(8)
        }

        let pieces = timePart.split(separator: ":")
        guard pieces.count >= 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        let second = pieces.count > 2 ? Int(pieces[2]) ?? -1 : 0
        guard (0...59).contains(second) else { return nil }
        return TimeInterval(hour * 3600 + minute * 60 + second)
    }

    static func date(from value: String, calendar: Calendar = .current) -> Date? {
        // 档案日期遵循 .NET DateTime.Date 语义，不应因设备时区变化而跨日。
        if value.count >= 10 {
            let prefix = value.prefix(10).split(separator: "-")
            if prefix.count == 3,
               let year = Int(prefix[0]),
               let month = Int(prefix[1]),
               let day = Int(prefix[2]) {
                let components = DateComponents(year: year, month: month, day: day)
                guard components.isValidDate(in: calendar),
                      let date = calendar.date(from: components) else { return nil }
                return date
            }
        }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        return nil
    }

    static func isSameDay(_ value: String, as date: Date, calendar: Calendar) -> Bool {
        guard let parsed = self.date(from: value, calendar: calendar) else { return false }
        return calendar.isDate(parsed, inSameDayAs: date)
    }
}
