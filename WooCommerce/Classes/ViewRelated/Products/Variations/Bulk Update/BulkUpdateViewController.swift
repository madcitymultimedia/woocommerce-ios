import UIKit
import Yosemite
import WordPressUI
import Combine

/// Displays a list of settings for the user to choose to bulk update them for all variations
///
final class BulkUpdateViewController: UIViewController, GhostableViewController {

    @IBOutlet private weak var tableView: UITableView!

    private let viewModel: BulkUpdateViewModel

    private var subscriptions = Set<AnyCancellable>()

    lazy var ghostTableViewController = GhostTableViewController(options: GhostTableViewOptions(sectionHeaderVerticalSpace: .large,
                                                                                                cellClass: ValueOneTableViewCell.self,
                                                                                                rowsPerSection: Constants.placeholderRowsPerSection,
                                                                                                isScrollEnabled: false))

    private var sections: [Section] = []

    /// Dedicated `NoticePresenter` because this controller is modally presented we use this here instead of ServiceLocator.noticePresenter
    ///
    private lazy var noticePresenter: NoticePresenter = {
        let noticePresenter = DefaultNoticePresenter()
        noticePresenter.presentingViewController = self
        return noticePresenter
    }()

    init(viewModel: BulkUpdateViewModel, noticePresenter: NoticePresenter? = nil) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        if let noticePresenter = noticePresenter {
            self.noticePresenter = noticePresenter
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        configureTableView()
        configureViewModel()
    }

    /// Configures the  title and navigation bar button
    ///
    private func configureNavigationBar() {
        title = Localization.screenTitle

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: Localization.cancelButtonTitle,
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(cancelButtonTapped))
    }

    /// Setup receiving updates for data changes and actives the view model
    ///
    private func configureViewModel() {
        viewModel.$syncState.sink { [weak self] state in
            guard let self = self else { return }

            switch state {
            // `.notStarted` is the initial state of the VM
            // and transition to this state is not possible
            case .notStarted:
                return
            case .syncing:
                self.sections = []
                self.displayGhostContent()
            case let .synced(sections):
                self.sections = sections
                self.removeGhostContent()
                self.tableView.reloadData()
                self.displayTooManyVariationsWarningIfNeeded()
            case .error:
                self.removeGhostContent()
                self.displaySyncingError()
            }
        }.store(in: &subscriptions)

        viewModel.syncVariations()
    }

    /// Configures the table view: registers Nibs & setup datasource / delegate
    ///
    private func configureTableView() {
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .listBackground

        registerTableViewHeaderSections()
        registerTableViewCells()

        tableView.dataSource = self
        tableView.delegate = self
    }

    private func registerTableViewHeaderSections() {
        let headerNib = UINib(nibName: TwoColumnSectionHeaderView.reuseIdentifier, bundle: nil)
        tableView.register(headerNib, forHeaderFooterViewReuseIdentifier: TwoColumnSectionHeaderView.reuseIdentifier)
    }

    private func registerTableViewCells() {
        for row in Row.allCases {
            tableView.registerNib(for: row.type)
        }
    }

    /// Action handler for the cancel button
    ///
    @objc private func cancelButtonTapped() {
        viewModel.handleTapCancel()
    }

    /// Displays the error `Notice`.
    ///
    private func displaySyncingError() {
        let title = Localization.noticeUnableToSyncVariations
        let actionTitle = Localization.noticeRetryAction
        let notice = Notice(title: title, feedbackType: .error, actionTitle: actionTitle) { [weak self] in
            self?.viewModel.syncVariations()
        }

        noticePresenter.enqueue(notice: notice)
    }

    /// Displays the success price update `Notice`.
    ///
    private func displayPriceUpdatedNotice() {
        let title = Localization.pricesUpdated
        let notice = Notice(title: title, feedbackType: .success)
        noticePresenter.enqueue(notice: notice)
    }

    /// Called when the price option is selected
    ///
    private func navigateToEditPriceSettings() {
        let bulkUpdatePriceSettingsViewModel = viewModel.viewModelForBulkUpdatePriceOfType(.regular, priceUpdateDidFinish: { [weak self] in
            guard let self = self else { return }
            self.navigationController?.popToViewController(self, animated: true)
            self.displayPriceUpdatedNotice()
        })
        let viewController = BulkUpdatePriceViewController(viewModel: bulkUpdatePriceSettingsViewModel)
        show(viewController, sender: nil)
    }

    /// Displays a warning informing the user that only the first 100 variations would be editted.
    /// This is due to API limitations.
    ///
    private func displayTooManyVariationsWarningIfNeeded() {
        guard viewModel.shouldShowVariationLimitWarning else {
            return
        }

        let bannerViewModel = TopBannerViewModel(title: nil,
                                    infoText: Localization.tooManyVariations,
                                    icon: .noticeImage,
                                    iconTintColor: .warning,
                                    isExpanded: false,
                                    topButton: .none,
                                    type: .warning)
        let banner = TopBannerView(viewModel: bannerViewModel)
        tableView.tableHeaderView = banner
        tableView.updateHeaderHeight()
    }
}

// MARK: - UITableViewDataSource Conformance
//
extension BulkUpdateViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rowAtIndexPath(indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)
        configure(cell, for: row, at: indexPath)

        return cell
    }
}

// MARK: - Cell configuration
//
private extension BulkUpdateViewController {
    /// Configures a cell
    ///
    func configure(_ cell: UITableViewCell, for row: Row, at indexPath: IndexPath) {
        switch cell {
        case let cell as ValueOneTableViewCell where row == .regularPrice:
            configureRegularPrice(cell: cell)
        default:
            fatalError("Unidentified bulk update row type")
            break
        }
    }

    /// Configures the user facing properties of the cell displaying the regular price option
    ///
    func configureRegularPrice(cell: ValueOneTableViewCell) {

        cell.configure(with: viewModel.viewModelForDisplayingRegularPrice())
    }
}

// MARK: - UITableViewDelegate Conformance
//
extension BulkUpdateViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rowAtIndexPath(indexPath)

        switch row {
        case .regularPrice:
            navigateToEditPriceSettings()
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return Constants.sectionHeight
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let leftText = sections[section].title else {
            return nil
        }

        let reuseIdentifier = TwoColumnSectionHeaderView.reuseIdentifier
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: reuseIdentifier) as? TwoColumnSectionHeaderView else {
            fatalError("Could not find section header view for reuseIdentifier \(reuseIdentifier)")
        }

        headerView.leftText = leftText
        headerView.rightText = nil

        return headerView
    }
}

// MARK: - Convenience Methods
//
private extension BulkUpdateViewController {
    func rowAtIndexPath(_ indexPath: IndexPath) -> Row {
        return sections[indexPath.section].rows[indexPath.row]
    }
}

extension BulkUpdateViewController {
    struct Section: Equatable {
        let title: String?
        let rows: [Row]
    }

    enum Row: CaseIterable {
        case regularPrice

        fileprivate var type: UITableViewCell.Type {
            return ValueOneTableViewCell.self
        }

        fileprivate var reuseIdentifier: String {
            return type.reuseIdentifier
        }
    }
}

private extension BulkUpdateViewController {
    enum Localization {
        static let cancelButtonTitle = NSLocalizedString("Cancel", comment: "Button title that closes the presented screen")
        static let screenTitle = NSLocalizedString("Bulk Update", comment: "Title that appears on top of the bulk update of product variations screen")
        static let noticeUnableToSyncVariations = NSLocalizedString("Unable to retrieve variations",
                                                                    comment: "Unable to retrieve variations for bulk update screen")
        static let noticeRetryAction = NSLocalizedString("Retry", comment: "Retry Action")
        static let pricesUpdated = NSLocalizedString("Prices updated successfully.",
                                                     comment: "Notice title when updating the price via the bulk variation screen")
        static let tooManyVariations = NSLocalizedString("Only the first 100 variations will be updated.",
                                                         comment: "Warning when trying to bulk edit more than 100 variations")
    }
}

private struct Constants {
    static let sectionHeight = CGFloat(44)
    static let placeholderRowsPerSection = [1]
}
