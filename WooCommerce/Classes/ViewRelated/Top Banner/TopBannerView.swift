import Gridicons
import UIKit

/// A full-width banner view to be shown at the top of a tab below the navigation bar.
/// Consists of an icon, text label, action button and dismiss button.
///
final class TopBannerView: UIView {
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView(image: nil)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var infoLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "top-banner-view-info-label"
        return label
    }()

    private lazy var dismissButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "top-banner-view-dismiss-button"
        return button
    }()

    private lazy var expandCollapseButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "top-banner-view-expand-collapse-button"
        return button
    }()

    private let actionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    private let titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        return stackView
    }()

    private let labelHolderStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        return stackView
    }()

    // StackView to hold the action buttons. Needed to change the axis on larger accessibility traits
    private let buttonsStackView = UIStackView()

    private let actionButtons: [UIButton]

    private let isActionEnabled: Bool

    private(set) var isExpanded: Bool

    private let onTopButtonTapped: (() -> Void)?

    init(viewModel: TopBannerViewModel) {
        isActionEnabled = viewModel.actionButtons.isNotEmpty
        isExpanded = viewModel.isExpanded
        onTopButtonTapped = viewModel.topButton.handler
        actionButtons = viewModel.actionButtons.map { _ in UIButton() }
        super.init(frame: .zero)
        configureSubviews(with: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TopBannerView {
    func configureSubviews(with viewModel: TopBannerViewModel) {
        let mainStackView = createMainStackView(with: viewModel)
        addSubview(mainStackView)
        pinSubviewToSafeArea(mainStackView)

        titleLabel.applyHeadlineStyle()
        titleLabel.numberOfLines = 0

        infoLabel.applyBodyStyle()
        infoLabel.numberOfLines = 0

        configureBannerType(type: viewModel.type)
        renderContent(of: viewModel)
        updateStackViewsAxis()
    }

    func renderContent(of viewModel: TopBannerViewModel) {
        // It is necessary to remove the subview when there is no text,
        // otherwise the stack view spacing stays, breaking the view.
        // See: https://github.com/woocommerce/woocommerce-ios/issues/8747
        if let title = viewModel.title, !title.isEmpty {
            titleLabel.text = title
        } else {
            titleLabel.removeFromSuperview()
        }

        if let infoText = viewModel.infoText, !infoText.isEmpty {
            infoLabel.text = infoText
        } else {
            labelHolderStackView.removeFromSuperview()
        }

        iconImageView.image = viewModel.icon
        if let color = viewModel.iconTintColor {
            iconImageView.tintColor = color
        }

        zip(viewModel.actionButtons, actionButtons).forEach { buttonInfo, button in
            button.setTitle(buttonInfo.title, for: .normal)
            button.titleLabel?.font = .boldSystemFont(ofSize: titleLabel.font.pointSize)
            // Overrides the general .applyLinkButtonStyle() with pink color
            // pecCkj-fa-p2
            button.setTitleColor(UIColor.withColorStudio(.pink), for: .normal)
            button.on(.touchUpInside, call: { _ in buttonInfo.action(button) })
        }
    }

    func configureTopButton(viewModel: TopBannerViewModel, onContentView contentView: UIView) {
        switch viewModel.topButton {
        case .chevron:
            updateExpandCollapseState(isExpanded: isExpanded)
            expandCollapseButton.tintColor = .textSubtle

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onExpandCollapseButtonTapped))
            tapGesture.cancelsTouchesInView = false
            contentView.addGestureRecognizer(tapGesture)

        case .dismiss:
            dismissButton.setImage(UIImage.gridicon(.cross, size: CGSize(width: 24, height: 24)), for: .normal)
            dismissButton.tintColor = .textSubtle
            dismissButton.addTarget(self, action: #selector(onDismissButtonTapped), for: .touchUpInside)
            titleStackView.accessibilityHint = Localization.dismissHint

        case .none:
            break
        }
    }

    func createMainStackView(with viewModel: TopBannerViewModel) -> UIStackView {
        let iconInformationStackView = createIconInformationStackView(with: viewModel)
        let mainStackView = UIStackView(arrangedSubviews: [createBorderView(), iconInformationStackView, createBorderView()])
        if isActionEnabled {
            configureActionStackView(with: viewModel)
            mainStackView.addArrangedSubview(actionStackView)
        }

        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        return mainStackView
    }

    func createIconInformationStackView(with viewModel: TopBannerViewModel) -> UIStackView {
        let informationStackView = createInformationStackView(with: viewModel)
        let iconInformationStackView = UIStackView(arrangedSubviews: [iconImageView, informationStackView])

        iconInformationStackView.translatesAutoresizingMaskIntoConstraints = false
        iconInformationStackView.axis = .horizontal
        iconInformationStackView.spacing = 16
        iconInformationStackView.alignment = .leading
        iconInformationStackView.layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)
        iconInformationStackView.isLayoutMarginsRelativeArrangement = true
        configureTopButton(viewModel: viewModel, onContentView: iconInformationStackView)

        return iconInformationStackView
    }

    func createLabelHolderStackView() -> UIStackView {
        labelHolderStackView.addArrangedSubviews([
            createSeparatorView(height: Constants.labelHolderHeight, width: Constants.labelHolderLeftMargin),
            infoLabel,
            createSeparatorView(height: Constants.labelHolderHeight, width: Constants.labelHolderRightMargin)
        ])
        labelHolderStackView.spacing = Constants.labelHolderSpacing
        infoLabel.adjustsFontSizeToFitWidth = true

        return labelHolderStackView
    }

    func createInformationStackView(with viewModel: TopBannerViewModel) -> UIStackView {
        let topActionButton = topButton(for: viewModel.topButton)
        titleStackView.addArrangedSubviews([titleLabel, topActionButton].compactMap { $0 })
        titleStackView.spacing = 16
        titleStackView.isAccessibilityElement = true
        titleStackView.accessibilityTraits = .button
        titleStackView.accessibilityLabel = viewModel.title
        titleStackView.accessibilityIdentifier = topActionButton?.accessibilityIdentifier

        // titleStackView will hidden if there is no title
        titleStackView.isHidden = viewModel.title == nil || viewModel.title?.isEmpty == true

        let informationStackView = UIStackView(arrangedSubviews: [titleStackView, createLabelHolderStackView()])

        informationStackView.axis = .vertical
        informationStackView.spacing = 9

        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        dismissButton.setContentHuggingPriority(.required, for: .horizontal)
        dismissButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        expandCollapseButton.setContentHuggingPriority(.required, for: .horizontal)
        expandCollapseButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        return informationStackView
    }

    func configureActionStackView(with viewModel: TopBannerViewModel) {
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 0.5

        // Background to simulate a separator by giving the buttons some spacing
        let separatorBackground = createButtonsBackgroundView()
        buttonsStackView.addSubview(separatorBackground)
        buttonsStackView.pinSubviewToAllEdges(separatorBackground)

        // Style buttons
        actionButtons.forEach { button in
            button.applyLinkButtonStyle()
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.backgroundColor = backgroundColor(for: viewModel.type)
            buttonsStackView.addArrangedSubview(button)
        }

        // Bundle everything with a vertical separator
        actionStackView.addArrangedSubviews([buttonsStackView, createBorderView()])
    }

    func createButtonsBackgroundView() -> UIView {
        let separatorBackground = UIView()
        separatorBackground.translatesAutoresizingMaskIntoConstraints = false
        separatorBackground.backgroundColor = .systemColor(.separator)
        return separatorBackground
    }

    func createBorderView() -> UIView {
        return UIView.createBorderView()
    }

    func createSeparatorView(height: CGFloat, width: CGFloat) -> UIView {
        return UIView.createSeparatorView(height: height, width: width)
    }

    func topButton(for buttonType: TopBannerViewModel.TopButtonType) -> UIButton? {
        switch buttonType {
        case .chevron:
            return expandCollapseButton
        case .dismiss:
            return dismissButton
        case .none:
            return nil
        }
    }

    func configureBannerType(type: TopBannerViewModel.BannerType) {
        switch type {
        case .normal:
            iconImageView.tintColor = .textSubtle
        case .warning:
            iconImageView.tintColor = .warning
        case .info:
            iconImageView.tintColor = .info
        }
        backgroundColor = backgroundColor(for: type)
    }

    func backgroundColor(for bannerType: TopBannerViewModel.BannerType) -> UIColor {
        switch bannerType {
        case .normal:
            return .systemColor(.secondarySystemGroupedBackground)
        case .warning:
            return .warningBackground
        case .info:
            return .infoBackground
        }
    }

    /// Changes the axis of the stack views that need special treatment on larger size categories
    ///
    func updateStackViewsAxis() {
        buttonsStackView.axis = traitCollection.preferredContentSizeCategory > .extraExtraExtraLarge ? .vertical : .horizontal
    }
}

private extension TopBannerView {
    @objc func onDismissButtonTapped() {
        onTopButtonTapped?()
    }

    @objc func onExpandCollapseButtonTapped() {
        self.isExpanded = !isExpanded
        updateExpandCollapseState(isExpanded: isExpanded)
        onTopButtonTapped?()
    }
}

// MARK: Accessibility Handling
//
extension TopBannerView {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateStackViewsAxis()
    }
}

// MARK: UI Updates
//
private extension TopBannerView {
    func updateExpandCollapseState(isExpanded: Bool) {
        let image = isExpanded ? UIImage.chevronUpImage: UIImage.chevronDownImage
        expandCollapseButton.setImage(image, for: .normal)
        labelHolderStackView.isHidden = !isExpanded
        if isActionEnabled {
            actionStackView.isHidden = !isExpanded
        }
        titleStackView.accessibilityHint = isExpanded ? Localization.collapseHint : Localization.expandHint
        titleStackView.accessibilityValue = isExpanded ? Localization.expanded : Localization.collapsed

        let accessibleView = isExpanded ? labelHolderStackView : nil
        UIAccessibility.post(notification: .layoutChanged, argument: accessibleView)
    }
}

// MARK: Constants
//
private extension TopBannerView {
    enum Localization {
        static let expanded = NSLocalizedString("Expanded", comment: "Accessibility value when a banner is expanded")
        static let collapsed = NSLocalizedString("Collapsed", comment: "Accessibility value when a banner is collapsed")
        static let expandHint = NSLocalizedString("Double-tap for more information", comment: "Accessibility hint to expand a banner")
        static let collapseHint = NSLocalizedString("Double-tap to collapse", comment: "Accessibility hint to collapse a banner")
        static let dismissHint = NSLocalizedString("Double-tap to dismiss", comment: "Accessibility hint to dismiss a banner")
    }
}

// MARK: - Constants
//
private extension TopBannerView {
    enum Constants {
        static let labelHolderHeight: CGFloat = 48.0
        static let labelHolderLeftMargin: CGFloat = 0.0
        static let labelHolderRightMargin: CGFloat = 24.0
        static let labelHolderSpacing: CGFloat = 1.0
    }
}
