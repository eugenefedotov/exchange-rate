import Foundation

extension Date {
    /// "сегодня в 10:45" или "20.11 в 23:00".
    public func ratesTimeText(now: Date = .now, calendar: Calendar = .current) -> String {
        let time = formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        if calendar.isDate(self, inSameDayAs: now) {
            return "сегодня в \(time)"
        }
        let day = formatted(.dateTime.day(.twoDigits).month(.twoDigits))
        return "\(day) в \(time)"
    }
}

extension RatesSnapshot {
    public func fetchedAtText(now: Date = .now, calendar: Calendar = .current) -> String {
        fetchedAt.ratesTimeText(now: now, calendar: calendar)
    }
}
