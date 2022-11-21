import Foundation
import UIKit



/// AccountHeaderView: Displays an Account's Details: [Gravatar + Name + Username]
///
class AccountHeaderView: UIView {

    /// Account's Gravatar.
    ///
    @IBOutlet private var gravatarImageView: UIImageView! {
        didSet {
            gravatarImageView.image = .gravatarPlaceholderImage
        }
    }

    /// Account's Full Name.
    ///
    @IBOutlet private var fullnameLabel: UILabel! {
        didSet {
            fullnameLabel.textColor = .systemColor(.label)
            fullnameLabel.accessibilityIdentifier = "full-name-label"
        }
    }

    /// Account's Username.
    ///
    @IBOutlet private var usernameLabel: UILabel! {
        didSet {
            usernameLabel.textColor = .systemColor(.secondaryLabel)
            usernameLabel.accessibilityIdentifier = "username-label"
        }
    }

    /// Help Button
    ///
    @IBOutlet private weak var helpButton: UIButton!

    @IBOutlet private var containerView: UIView!

    /// Closure to be executed whenever the help button is pressed
    ///
    var onHelpRequested: (() -> Void)?

    // MARK: - Overridden Methods

    override func awakeFromNib() {
        super.awakeFromNib()
        setupHelpButton()
        configureContainerView()
    }
}


// MARK: - Public Methods
//
extension AccountHeaderView {

    /// Account's Username.
    ///
    var username: String? {
        set {
            usernameLabel.text = newValue
        }
        get {
            return usernameLabel.text
        }
    }

    /// Account's Full Name
    ///
    var fullname: String? {
        set {
            fullnameLabel.text = newValue
        }
        get {
            return fullnameLabel.text
        }
    }

    var isHelpButtonEnabled: Bool {
        set {
            helpButton.isHidden = !newValue
            helpButton.isEnabled = newValue
        }
        get {
            return helpButton.isHidden
        }
    }

    /// Downloads (and displays) the Gravatar associated with the specified Email.
    ///
    func downloadGravatar(with email: String) {
        gravatarImageView.downloadGravatarWithEmail(email)
    }
}


// MARK: - Private Methods
//
private extension AccountHeaderView {

    func configureContainerView() {
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.border.cgColor
        containerView.layer.cornerRadius = 8
    }

    func setupHelpButton() {
        helpButton.setTitle(Strings.helpButtonTitle, for: .normal)
        helpButton.setTitleColor(.accent, for: .normal)
        helpButton.on(.touchUpInside) { [weak self] control in
            ServiceLocator.analytics.track(.sitePickerHelpButtonTapped)
            self?.handleHelpButtonTapped(control)
        }
    }

    /// Handle the help button being tapped
    ///
    func handleHelpButtonTapped(_ sender: AnyObject) {
        onHelpRequested?()
    }
}


// MARK: - Constants!
//
private extension AccountHeaderView {

    enum Strings {
        static let helpButtonTitle = NSLocalizedString("Help", comment: "Help button on store picker screen.")
    }
}
