import Foundation
import UIKit


/// Empty Stores: Displayed whenever there are no available WooCommerce Stores associated with the active account.
///
final class EmptyStoresTableViewCell: UITableViewCell {

    var onCloseAccountButtonTapped: (() -> Void)?

    /// LegendLabel: To be displayed below the ImageView.
    ///
    @IBOutlet private var legendLabel: UILabel! {
        didSet {
            legendLabel.textColor = .text
            legendLabel.font = .title3SemiBold
            legendLabel.text = Localization.legend
        }
    }

    @IBOutlet private var subtitleLabel: UILabel! {
        didSet {
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.font = .body
            subtitleLabel.text = Localization.subtitle
        }
    }

    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var emptyStoresImageView: UIImageView!
    @IBOutlet private weak var removeAppleIDAccessButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        configureStackView()
        configureImageView()
        configureRemoveAppleIDAccessButton()
        updateRemoveAppleIDAccessButtonVisibility(isVisible: false)
    }

    func updateRemoveAppleIDAccessButtonVisibility(isVisible: Bool) {
        removeAppleIDAccessButton.isHidden = !isVisible
    }
}


private extension EmptyStoresTableViewCell {

    func configureStackView() {
        stackView.spacing = 24
        stackView.alignment = .center
    }

    func configureImageView() {
        emptyStoresImageView.contentMode = .scaleAspectFit
        emptyStoresImageView.image = .emptyStorePickerImage
    }

    func configureRemoveAppleIDAccessButton() {
        removeAppleIDAccessButton.applyLinkButtonStyle()
        removeAppleIDAccessButton.setTitle(Localization.closeAccountTitle, for: .normal)
        removeAppleIDAccessButton.on(.touchUpInside) { [weak self] _ in
            self?.onCloseAccountButtonTapped?()
        }
    }
}

private extension EmptyStoresTableViewCell {
    enum Localization {
        static let closeAccountTitle = NSLocalizedString(
            "Close Account",
            comment: "Link on the store picker for users who signed in with Apple to close their WordPress.com account."
        )
        static let legend =
            NSLocalizedString("Create your first store",
                              comment: "Displayed during the Login flow, whenever the user has no woo stores associated.")
        static let subtitle = NSLocalizedString("Quickly get up and selling with a beautiful online store.",
                                                comment: "Subtitle displayed during the Login flow, whenever the user has no woo stores associated.")
    }
}
