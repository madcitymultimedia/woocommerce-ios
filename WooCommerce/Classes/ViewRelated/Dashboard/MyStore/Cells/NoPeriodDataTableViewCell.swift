import Foundation
import UIKit


/// Displayed whenever there is no top performer data for a given period (granularity)
///
final class NoPeriodDataTableViewCell: UITableViewCell {
    @IBOutlet private weak var mainImageView: UIImageView!

    /// LegendLabel: To be displayed below the ImageView.
    ///
    @IBOutlet private var legendLabel: UILabel! {
        didSet {
            legendLabel.applySubheadlineStyle()
            legendLabel.text = NSLocalizedString(
                "No activity this period",
                comment: "Default text for Top Performers section when no data exists for a given period."
            )
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.backgroundColor = Constants.backgroundColor
        backgroundColor = .listForeground(modal: false)
    }
}

private extension NoPeriodDataTableViewCell {
    enum Constants {
        static let backgroundColor: UIColor = .systemBackground
    }
}
