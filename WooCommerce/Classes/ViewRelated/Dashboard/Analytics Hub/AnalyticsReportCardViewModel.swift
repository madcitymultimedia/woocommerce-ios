import Foundation
import class UIKit.UIColor

/// Analytics Hub Report Card ViewModel.
/// Used to transmit analytics report data.
///
struct AnalyticsReportCardViewModel {
    /// Report Card Title.
    ///
    let title: String

    /// First Column Title
    ///
    let leadingTitle: String

    /// First Column Value
    ///
    let leadingValue: String

    /// First Column Delta Value
    ///
    let leadingDelta: String

    /// First Column delta background color.
    ///
    let leadingDeltaColor: UIColor

    /// First Column Chart Data
    ///
    let leadingChartData: [Double]

    /// Second Column Title
    ///
    let trailingTitle: String

    /// Second Column Value
    ///
    let trailingValue: String

    /// Second Column Delta Value
    ///
    let trailingDelta: String

    /// Second Column Delta Background Color
    ///
    let trailingDeltaColor: UIColor

    /// Second Column Chart Data
    ///
    let trailingChartData: [Double]

    /// Indicates if the values should be hidden (for loading state)
    ///
    let isRedacted: Bool

    /// Indicates if there was an error loading the data for the card
    ///
    let showSyncError: Bool

    /// Message to display if there was an error loading the data for the card
    ///
    let syncErrorMessage: String
}

extension AnalyticsReportCardViewModel {

    /// Make redacted state of the card, replacing values with hardcoded placeholders
    ///
    var redacted: Self {
        // Values here are placeholders and will be redacted in the UI
        .init(title: title,
              leadingTitle: leadingTitle,
              leadingValue: "$1000",
              leadingDelta: "+50%",
              leadingDeltaColor: .lightGray,
              leadingChartData: [],
              trailingTitle: trailingTitle,
              trailingValue: "$1000",
              trailingDelta: "+50%",
              trailingDeltaColor: .lightGray,
              trailingChartData: [],
              isRedacted: true,
              showSyncError: false,
              syncErrorMessage: "")
    }
}
