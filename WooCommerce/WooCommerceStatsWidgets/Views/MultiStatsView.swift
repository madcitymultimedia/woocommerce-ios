 import SwiftUI

 struct MultiStatsView: View {
    let viewData: MultiStatViewModel

    var body: some View {
        VStack(alignment: .leading) {
            FlexibleCard(axis: .horizontal,
                         title: viewData.widgetTitle,
                         value: .description(viewData.siteName))
            Spacer()
            HStack {
                makeColumn(upperTitle: viewData.upperLeftTitle,
                           upperValue: viewData.upperLeftValue,
                           lowerTitle: viewData.lowerLeftTitle,
                           lowerValue: viewData.lowerLeftValue)
                Spacer()
                Spacer()
                makeColumn(upperTitle: viewData.upperRightTitle,
                           upperValue: viewData.upperRightValue,
                           lowerTitle: viewData.lowerRightTitle,
                           lowerValue: viewData.lowerRightValue)
                Spacer()
            }
        }
    }

    /// Constructs a two-card column for the medium size Today widget
    private func makeColumn(upperTitle: String,
                            upperValue: String,
                            lowerTitle: String,
                            lowerValue: String) -> some View {
        VStack(alignment: .leading) {
            VerticalCard(title: upperTitle, value: upperValue, largeText: false)
            Spacer()
            VerticalCard(title: lowerTitle, value: lowerValue, largeText: false)
        }
    }
 }
