import UIKit

// NOTE: this file is adapted from WPiOS at the following path:
// https://github.com/wordpress-mobile/WordPress-iOS/blob/c67f3b6205c1bc40085b390ec5e46faf5e281df9/
// WordPress/Classes/ViewRelated/Reader/Manage/TabbedViewController.swift

/// Contains multiple Child View Controllers with a Filter Tab Bar to switch between them.
class TabbedViewController: UIViewController {

    struct TabbedItem: FilterTabBarItem {
        let title: String
        let viewController: UIViewController
        let accessibilityIdentifier: String
    }

    /// The selected view controller
    var selection: Int {
        set {
            tabBar.setSelectedIndex(newValue)
        }
        get {
            return tabBar.selectedIndex
        }
    }

    private let items: [TabbedItem]
    private let onDismiss: (() -> Void)?

    private(set) lazy var tabBar: FilterTabBar = {
        let bar = FilterTabBar()
        configureFilterTabBar(bar)
        bar.tabSizingStyle = .equalWidths
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addTarget(self, action: #selector(changedItem(sender:)), for: .valueChanged)
        return bar
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        return stackView
    }()

    private weak var child: UIViewController? {
        didSet {
            oldValue?.remove()

            if let child = child, child.parent != self {
                addChild(child)
                stackView.addArrangedSubview(child.view)
                child.didMove(toParent: self)
            }
        }
    }

    init(items: [TabbedItem], tabSizingStyle: FilterTabBar.TabSizingStyle, onDismiss: (() -> Void)? = nil) {
        self.items = items
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        tabBar.items = items
        tabBar.tabSizingStyle = tabSizingStyle

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))

        stackView.addArrangedSubview(tabBar)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func donePressed() {
        onDismiss?()
        dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(stackView)
        view.pinSubviewToAllEdges(stackView)

        setInitialChild()
    }

    private func setInitialChild() {
        let initialItem: TabbedItem = items[selection]
        child = initialItem.viewController
    }

    @objc func changedItem(sender: FilterTabBar) {
        let item = items[sender.selectedIndex]
        child = item.viewController
        selection = sender.selectedIndex
    }
}

private extension TabbedViewController {
    func configureFilterTabBar(_ filterTabBar: FilterTabBar) {
        filterTabBar.backgroundColor = .systemColor(.secondarySystemGroupedBackground)
        filterTabBar.tintColor = .primary
        filterTabBar.selectedTitleColor = .primary
        filterTabBar.deselectedTabColor = .textSubtle
        filterTabBar.dividerColor = .systemColor(.separator)
    }
}
