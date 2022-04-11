import Yosemite

/// Implementation of `SearchUICommand` for Order search.
final class OrderSearchUICommand: SearchUICommand {
    typealias Model = Order
    typealias CellViewModel = OrderListCellViewModel
    typealias ResultsControllerModel = StorageOrder

    private lazy var featureFlagService = ServiceLocator.featureFlagService

    let searchBarPlaceholder = NSLocalizedString("Search all orders", comment: "Orders Search Placeholder")

    let searchBarAccessibilityIdentifier = "order-search-screen-search-field"

    let cancelButtonAccessibilityIdentifier = "order-search-screen-cancel-button"

    private lazy var statusResultsController: ResultsController<StorageOrderStatus> = {
        let storageManager = ServiceLocator.storageManager
        let predicate = NSPredicate(format: "siteID == %lld", siteID)
        let descriptor = NSSortDescriptor(key: "slug", ascending: true)

        return ResultsController<StorageOrderStatus>(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])
    }()

    private let siteID: Int64

    init(siteID: Int64) {
        self.siteID = siteID
        configureResultsController()
    }

    func createResultsController() -> ResultsController<ResultsControllerModel> {
        let storageManager = ServiceLocator.storageManager
        let predicate = NSPredicate(format: "siteID == %lld", siteID)
        let descriptor = NSSortDescriptor(keyPath: \StorageOrder.dateCreated, ascending: false)
        return ResultsController<StorageOrder>(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])
    }

    func createStarterViewController() -> UIViewController? {
        nil
    }

    func configureEmptyStateViewControllerBeforeDisplay(viewController: EmptyStateViewController,
                                                        searchKeyword: String) {
        let boldSearchKeyword = NSAttributedString(string: searchKeyword,
                                                   attributes: [.font: EmptyStateViewController.Config.messageFont.bold])

        let format = NSLocalizedString("We're sorry, we couldn't find results for “%@”",
                                       comment: "Message for empty Orders search results. The %@ is a placeholder for the text entered by the user.")
        let message = NSMutableAttributedString(string: format)
        message.replaceFirstOccurrence(of: "%@", with: boldSearchKeyword)

        viewController.configure(.simple(message: message, image: .emptySearchResultsImage))
    }

    func createCellViewModel(model: Order) -> OrderListCellViewModel {
        let orderStatus = lookUpOrderStatus(for: model)
        return OrderListCellViewModel(order: model, status: orderStatus)
    }

    /// Synchronizes the Orders matching a given Keyword
    ///
    func synchronizeModels(siteID: Int64, keyword: String, pageNumber: Int, pageSize: Int, onCompletion: ((Bool) -> Void)?) {
        let action = OrderAction.searchOrders(siteID: siteID, keyword: keyword, pageNumber: pageNumber, pageSize: pageSize) { error in
            if let error = error {
                DDLogError("☠️ Order Search Failure! \(error)")
            }

            onCompletion?(error == nil)
        }

        ServiceLocator.stores.dispatch(action)
        ServiceLocator.analytics.track(.ordersListSearch, withProperties: ["search": "\(keyword)"])
    }

    func didSelectSearchResult(model: Order, from viewController: UIViewController, reloadData: () -> Void, updateActionButton: () -> Void) {
        let viewModel = OrderDetailsViewModel(order: model)
        let detailsViewController = OrderDetailsViewController(viewModel: viewModel)

        viewController.navigationController?.pushViewController(detailsViewController, animated: true)
    }

    /// Removes the `#` from the start of the search keyword, if present.
    ///
    /// This allows searching for an order with `#123` and getting the results for order `123`.
    /// See https://github.com/woocommerce/woocommerce-ios/issues/2506
    ///
    func sanitizeKeyword(_ keyword: String) -> String {
        if keyword.starts(with: "#") {
            return keyword.removing(at: keyword.startIndex)
        }
        return keyword
    }
}

private extension OrderSearchUICommand {
    func configureResultsController() {
        try? statusResultsController.performFetch()
    }

    func lookUpOrderStatus(for order: Order) -> OrderStatus? {
        let listAll = statusResultsController.fetchedObjects
        for orderStatus in listAll where orderStatus.status == order.status {
            return orderStatus
        }

        return nil
    }
}
