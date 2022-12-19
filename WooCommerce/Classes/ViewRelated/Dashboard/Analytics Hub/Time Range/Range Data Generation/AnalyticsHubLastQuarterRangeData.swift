import Foundation

/// Responsible for defining two ranges of data, one starting from the first day of the last quarter
/// until the final day of that same quarter, and the previous one as two quarters ago, also starting
/// from the first day until the final day of that quarter. E. g.
///
/// Today: 29 Jul 2022
/// Current range: Apr 1 until Jun 30, 2022
/// Previous range: Jan 1 until Mar 31, 2022
///
struct AnalyticsHubLastQuarterRangeData: AnalyticsHubTimeRangeData {
    let currentDateStart: Date?
    let currentDateEnd: Date?
    let previousDateStart: Date?
    let previousDateEnd: Date?

    init(referenceDate: Date, timezone: TimeZone, calendar: Calendar) {
        let oneQuarterAgo = calendar.date(byAdding: .month, value: -3, to: referenceDate)
        self.currentDateEnd = oneQuarterAgo?.endOfQuarter(timezone: timezone, calendar: calendar)
        self.currentDateStart = oneQuarterAgo?.startOfQuarter(timezone: timezone, calendar: calendar)

        let twoQuartersAgo = calendar.date(byAdding: .month, value: -6, to: referenceDate)
        self.previousDateEnd = twoQuartersAgo?.endOfQuarter(timezone: timezone, calendar: calendar)
        self.previousDateStart = twoQuartersAgo?.startOfQuarter(timezone: timezone, calendar: calendar)
    }
}
