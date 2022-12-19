import Foundation

/// Responsible for defining two ranges of data, one starting from January 1st  of the current year
/// until the current date and the previous one, starting from January 1st of the last year
/// until the same day on the in that year. E. g.
///
/// Today: 1 Jul 2022
/// Current range: Jan 1 until Jul 1, 2022
/// Previous range: Jan 1 until Jul 1, 2022
///
struct AnalyticsHubYearToDateRangeData: AnalyticsHubTimeRangeData {
    let currentDateStart: Date?
    let currentDateEnd: Date?
    let previousDateStart: Date?
    let previousDateEnd: Date?

    init(referenceDate: Date, timezone: TimeZone, calendar: Calendar) {
        self.currentDateEnd = referenceDate
        self.currentDateStart = referenceDate.startOfYear(timezone: timezone)
        let previousDateEnd = calendar.date(byAdding: .year, value: -1, to: referenceDate)
        self.previousDateEnd = previousDateEnd
        self.previousDateStart = previousDateEnd?.startOfYear(timezone: timezone)
    }
}
