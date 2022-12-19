import Foundation

/// Responsible for defining two ranges of data, one starting from the first day of the current week
/// until the current date and the previous one, starting from the first day of the previous week
/// until the same day of that week. E. g.
///
/// Today: 29 Jul 2022
/// Current range: Jul 25 until Jul 29, 2022
/// Previous range: Jul 18 until Jul 22, 2022
///
struct AnalyticsHubWeekToDateRangeData: AnalyticsHubTimeRangeData {
    let currentDateStart: Date?
    let currentDateEnd: Date?
    let previousDateStart: Date?
    let previousDateEnd: Date?

    init(referenceDate: Date, timezone: TimeZone, calendar: Calendar) {
        self.currentDateEnd = referenceDate
        self.currentDateStart = referenceDate.startOfWeek(timezone: timezone, calendar: calendar)
        let previousDateEnd = calendar.date(byAdding: .day, value: -7, to: referenceDate)
        self.previousDateEnd = previousDateEnd
        self.previousDateStart = previousDateEnd?.startOfWeek(timezone: timezone, calendar: calendar)
    }
}
