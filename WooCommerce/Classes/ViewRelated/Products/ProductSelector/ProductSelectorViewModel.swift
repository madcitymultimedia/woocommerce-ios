import Yosemite
import protocol Storage.StorageManagerType
import Combine
import Foundation

/// View model for `ProductSelector`.
///
final class ProductSelectorViewModel: ObservableObject {
    private let siteID: Int64

    /// Storage to fetch product list
    ///
    private let storageManager: StorageManagerType

    /// Stores to sync product list
    ///
    private let stores: StoresManager

    /// Store for publishers subscriptions
    ///
    private var subscriptions = Set<AnyCancellable>()

    /// Trigger to perform any one time setups.
    ///
    let onLoadTrigger: PassthroughSubject<Void, Never> = PassthroughSubject()

    /// Defines the current notice that should be shown.
    /// Defaults to `nil`.
    ///
    @Published var notice: Notice?

    /// All products that can be added to an order.
    ///
    @Published private var products: [Product] = []

    /// View models for each product row
    ///
    @Published private(set) var productRows: [ProductRowViewModel] = []

    /// Closure to be invoked when a product is selected
    ///
    private let onProductSelected: ((Product) -> Void)?

    /// Closure to be invoked when a product variation is selected
    ///
    private let onVariationSelected: ((ProductVariation) -> Void)?

    /// Closure to be invoked when multiple selection is completed
    ///
    private let onMultipleSelectionCompleted: (([Int64]) -> Void)?

    // MARK: Sync & Storage properties

    /// Current sync status; used to determine what list view to display.
    ///
    @Published private(set) var syncStatus: SyncStatus?

    /// SyncCoordinator: Keeps tracks of which pages have been refreshed, and encapsulates the "What should we sync now" logic.
    ///
    private let syncingCoordinator = SyncingCoordinator()

    /// Tracks if the infinite scroll indicator should be displayed
    ///
    @Published private(set) var shouldShowScrollIndicator = false

    /// View models of the ghost rows used during the loading process.
    ///
    var ghostRows: [ProductRowViewModel] {
        return Array(0..<6).map { index in
            ghostProductRow(id: index)
        }
    }

    /// Products Results Controller.
    ///
    private lazy var productsResultsController: ResultsController<StorageProduct> = {
        let predicate = NSPredicate(format: "siteID == %lld", siteID)
        let descriptor = NSSortDescriptor(key: "name", ascending: true)
        let resultsController = ResultsController<StorageProduct>(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])
        return resultsController
    }()

    /// Predicate for the results controller.
    ///
    private lazy var resultsPredicate: NSPredicate? = {
        productsResultsController.predicate
    }()

    /// Current search term entered by the user.
    /// Each update will trigger a remote product search and sync.
    @Published var searchTerm: String = ""

    /// All selected products if the selector supports multiple selections.
    ///
    @Published private var selectedProductIDs: [Int64] = []

    /// All selected product variations if the selector supports multiple selections.
    ///
    @Published private var selectedProductVariationIDs: [Int64] = []

    var totalSelectedItemsCount: Int {
        selectedProductIDs.count + selectedProductVariationIDs.count
    }

    /// IDs of selected products and variations from initializer.
    ///
    private let initialSelectedItems: [Int64]

    /// Initializer for single selection
    ///
    init(siteID: Int64,
         storageManager: StorageManagerType = ServiceLocator.storageManager,
         stores: StoresManager = ServiceLocator.stores,
         onProductSelected: ((Product) -> Void)? = nil,
         onVariationSelected: ((ProductVariation) -> Void)? = nil) {
        self.siteID = siteID
        self.storageManager = storageManager
        self.stores = stores
        self.onProductSelected = onProductSelected
        self.onVariationSelected = onVariationSelected
        self.onMultipleSelectionCompleted = nil
        self.initialSelectedItems = []

        configureSyncingCoordinator()
        configureProductsResultsController()
        configureFirstPageLoad()
        configureProductSearch()
    }

    /// Initializer for multiple selections
    ///
    init(siteID: Int64,
         selectedItemIDs: [Int64],
         storageManager: StorageManagerType = ServiceLocator.storageManager,
         stores: StoresManager = ServiceLocator.stores,
         onMultipleSelectionCompleted: (([Int64]) -> Void)? = nil) {
        self.siteID = siteID
        self.storageManager = storageManager
        self.stores = stores
        self.onProductSelected = nil
        self.onVariationSelected = nil
        self.onMultipleSelectionCompleted = onMultipleSelectionCompleted
        self.initialSelectedItems = selectedItemIDs

        configureSyncingCoordinator()
        configureProductsResultsController()
        configureFirstPageLoad()
        configureProductSearch()
    }

    /// Select a product to add to the order
    ///
    func selectProduct(_ productID: Int64) {
        guard let selectedProduct = products.first(where: { $0.productID == productID }) else {
            return
        }
        if let onProductSelected = onProductSelected {
            onProductSelected(selectedProduct)
        } else {
            toggleSelection(productID: productID)
        }
    }

    /// Get the view model for a list of product variations to add to the order
    ///
    func getVariationsViewModel(for productID: Int64) -> ProductVariationSelectorViewModel? {
        guard let variableProduct = products.first(where: { $0.productID == productID }), variableProduct.variations.isNotEmpty else {
            return nil
        }
        return ProductVariationSelectorViewModel(siteID: siteID,
                                                 product: variableProduct,
                                                 selectedProductVariationIDs: selectedProductVariationIDs,
                                                 onVariationSelected: onVariationSelected)
    }

    /// Clears the current search term to display the full product list.
    ///
    func clearSearch() {
        searchTerm = ""
    }

    /// Updates selected variation list based on the new selected IDs
    ///
    func updateSelectedVariations(productID: Int64, selectedVariationIDs: [Int64]) {
        guard let variableProduct = products.first(where: { $0.productID == productID }),
              variableProduct.variations.isNotEmpty else {
            return
        }
        // remove all previous selected variations
        selectedProductVariationIDs.removeAll(where: { variableProduct.variations.contains($0) })
        // append new selected IDs
        selectedProductVariationIDs.append(contentsOf: selectedVariationIDs)
        // update product rows
        productRows = generateProductRows(products: products,
                                          selectedProductIDs: selectedProductIDs,
                                          selectedProductVariationIDs: selectedProductVariationIDs)
    }

    /// Triggers completion closure when the multiple selection completes.
    ///
    func completeMultipleSelection() {
        let allIDs = selectedProductIDs + selectedProductVariationIDs
        onMultipleSelectionCompleted?(allIDs)
    }
}

// MARK: - SyncingCoordinatorDelegate & Sync Methods
extension ProductSelectorViewModel: SyncingCoordinatorDelegate {
    /// Sync products from remote.
    ///
    func sync(pageNumber: Int, pageSize: Int, reason: String? = nil, onCompletion: ((Bool) -> Void)?) {
        transitionToSyncingState()

        if searchTerm.isNotEmpty {
            searchProducts(siteID: siteID, keyword: searchTerm, pageNumber: pageNumber, pageSize: pageSize, onCompletion: onCompletion)
        } else {
            syncProducts(pageNumber: pageNumber, pageSize: pageSize, reason: reason, onCompletion: onCompletion)
        }
    }

    /// Sync all products from remote.
    ///
    private func syncProducts(pageNumber: Int, pageSize: Int, reason: String? = nil, onCompletion: ((Bool) -> Void)?) {
        let action = ProductAction.synchronizeProducts(siteID: siteID,
                                                       pageNumber: pageNumber,
                                                       pageSize: pageSize,
                                                       stockStatus: nil,
                                                       productStatus: nil,
                                                       productType: nil,
                                                       productCategory: nil,
                                                       sortOrder: .nameAscending,
                                                       shouldDeleteStoredProductsOnFirstPage: false) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                self.updateProductsResultsController()
            case .failure(let error):
                self.notice = NoticeFactory.productSyncNotice() { [weak self] in
                    self?.sync(pageNumber: pageNumber, pageSize: pageSize, onCompletion: nil)
                }
                DDLogError("⛔️ Error synchronizing products during order creation: \(error)")
            }

            self.transitionToResultsUpdatedState()
            onCompletion?(result.isSuccess)
        }
        stores.dispatch(action)
    }

    /// Sync products matching a given keyword.
    ///
    private func searchProducts(siteID: Int64, keyword: String, pageNumber: Int, pageSize: Int, onCompletion: ((Bool) -> Void)?) {
        let action = ProductAction.searchProducts(siteID: siteID,
                                                  keyword: keyword,
                                                  pageNumber: pageNumber,
                                                  pageSize: pageSize) { [weak self] result in
            // Don't continue if this isn't the latest search.
            guard let self = self, keyword == self.searchTerm else {
                return
            }

            switch result {
            case .success:
                self.updateProductsResultsController()
            case .failure(let error):
                self.notice = NoticeFactory.productSearchNotice() { [weak self] in
                    self?.searchProducts(siteID: siteID, keyword: keyword, pageNumber: pageNumber, pageSize: pageSize, onCompletion: nil)
                }
                DDLogError("⛔️ Error searching products during order creation: \(error)")
            }

            self.transitionToResultsUpdatedState()
            onCompletion?(result.isSuccess)
        }

        stores.dispatch(action)
    }

    /// Sync first page of products from remote if needed.
    ///
    func syncFirstPage() {
        syncingCoordinator.synchronizeFirstPage()
    }

    /// Sync next page of products from remote.
    ///
    func syncNextPage() {
        let lastIndex = productsResultsController.numberOfObjects - 1
        syncingCoordinator.ensureNextPageIsSynchronized(lastVisibleIndex: lastIndex)
    }
}

// MARK: - Finite State Machine Management
private extension ProductSelectorViewModel {
    /// Update state for sync from remote.
    ///
    func transitionToSyncingState() {
        shouldShowScrollIndicator = true
        notice = nil
        if products.isEmpty {
            syncStatus = .firstPageSync
        }
    }

    /// Update state after sync is complete.
    ///
    func transitionToResultsUpdatedState() {
        shouldShowScrollIndicator = false
        syncStatus = products.isNotEmpty ? .results: .empty
    }
}

// MARK: - Configuration
private extension ProductSelectorViewModel {
    /// Performs initial fetch from storage and updates sync status accordingly.
    ///
    func configureProductsResultsController() {
        updateProductsResultsController()
        transitionToResultsUpdatedState()
    }

    /// Fetches products from storage.
    ///
    func updateProductsResultsController() {
        do {
            try productsResultsController.performFetch()
            products = productsResultsController.fetchedObjects.filter { $0.purchasable }
            updateSelectionsFromInitialSelectedItems()
            observeSelections()
        } catch {
            DDLogError("⛔️ Error fetching products for new order: \(error)")
        }
    }

    /// Setup: Syncing Coordinator
    ///
    func configureSyncingCoordinator() {
        syncingCoordinator.delegate = self
    }

    /// Performs initial sync on first page load
    ///
    func configureFirstPageLoad() {
        // Listen only to the first emitted event.
        onLoadTrigger.first()
            .sink { [weak self] in
                guard let self = self else { return }
                self.syncFirstPage()
            }
            .store(in: &subscriptions)
    }

    /// Updates the product results predicate & triggers a new sync when search term changes
    ///
    func configureProductSearch() {
        $searchTerm
            .dropFirst() // Drop initial value
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newSearchTerm in
                guard let self = self else { return }

                if newSearchTerm.isNotEmpty {
                    // When the search query changes, also includes the original results predicate in addition to the search keyword.
                    let searchResultsPredicate = NSPredicate(format: "ANY searchResults.keyword = %@", newSearchTerm)
                    let subpredicates = [self.resultsPredicate, searchResultsPredicate].compactMap { $0 }
                    self.productsResultsController.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                } else {
                    // Resets the results to the full product list when there is no search query.
                    self.productsResultsController.predicate = self.resultsPredicate
                }

                self.syncingCoordinator.resynchronize()
            }.store(in: &subscriptions)
    }
}

// MARK: - Multiple selection support
private extension ProductSelectorViewModel {
    /// Toggles the selection of the specified product.
    ///
    func toggleSelection(productID: Int64) {
        if selectedProductIDs.contains(productID) {
            selectedProductIDs.removeAll(where: { $0 == productID })
        } else {
            selectedProductIDs.append(productID)
        }
    }

    /// Update selected product and variation IDs from initial selected items
    ///
    func updateSelectionsFromInitialSelectedItems() {
        guard initialSelectedItems.isNotEmpty else {
            return
        }
        for id in initialSelectedItems {
            guard !selectedProductIDs.contains(id) && !selectedProductVariationIDs.contains(id) else {
                continue
            }
            if products.contains(where: { $0.productID == id }) {
                selectedProductIDs.append(id)
            } else {
                selectedProductVariationIDs.append(id)
            }
        }
    }

    /// Observes changes in selections to update product rows
    ///
    func observeSelections() {
        $products.combineLatest($selectedProductIDs) { [weak self] products, selectedProductIDs -> [ProductRowViewModel] in
            guard let self = self else {
                return []
            }
            return self.generateProductRows(products: products,
                                            selectedProductIDs: selectedProductIDs,
                                            selectedProductVariationIDs: self.selectedProductVariationIDs)
        }.assign(to: &$productRows)
    }

    /// Generates product rows based on products and selected product/variation IDs
    ///
    func generateProductRows(products: [Product], selectedProductIDs: [Int64], selectedProductVariationIDs: [Int64]) -> [ProductRowViewModel] {
        return products.map { product in
            var selectedState: ProductRow.SelectedState
            if product.variations.isEmpty {
                selectedState = selectedProductIDs.contains(product.productID) ? .selected : .notSelected
            } else {
                let intersection = Set(product.variations).intersection(Set(selectedProductVariationIDs))
                if intersection.isEmpty {
                    selectedState = .notSelected
                } else if intersection.count == product.variations.count {
                    selectedState = .selected
                } else {
                    selectedState = .partiallySelected
                }
            }
            return ProductRowViewModel(product: product, canChangeQuantity: false, selectedState: selectedState)
        }
    }
}

// MARK: - Utils
extension ProductSelectorViewModel {
    /// Represents possible statuses for syncing products
    ///
    enum SyncStatus {
        case firstPageSync
        case results
        case empty
    }

    /// Used for ghost list view while syncing
    ///
    private func ghostProductRow(id: Int64) -> ProductRowViewModel {
        ProductRowViewModel(productOrVariationID: id,
                            name: "Ghost Product",
                            sku: nil,
                            price: "20",
                            stockStatusKey: ProductStockStatus.inStock.rawValue,
                            stockQuantity: 1,
                            manageStock: false,
                            canChangeQuantity: false,
                            imageURL: nil)
    }

    /// Add Product to Order notices
    ///
    enum NoticeFactory {
        /// Returns a product sync error notice with a retry button.
        ///
        static func productSyncNotice(retryAction: @escaping () -> Void) -> Notice {
            Notice(title: Localization.syncErrorMessage, feedbackType: .error, actionTitle: Localization.errorActionTitle) {
                retryAction()
            }
        }

        /// Returns a product search error notice with a retry button.
        ///
        static func productSearchNotice(retryAction: @escaping () -> Void) -> Notice {
            Notice(title: Localization.searchErrorMessage, feedbackType: .error, actionTitle: Localization.errorActionTitle) {
                retryAction()
            }
        }
    }
}

private extension ProductSelectorViewModel {
    enum Localization {
        static let syncErrorMessage = NSLocalizedString("There was an error syncing products",
                                                        comment: "Notice displayed when syncing the list of products fails")
        static let searchErrorMessage = NSLocalizedString("There was an error searching products",
                                                          comment: "Notice displayed when searching the list of products fails")
        static let errorActionTitle = NSLocalizedString("Retry", comment: "Retry action for an error notice")
    }
}
