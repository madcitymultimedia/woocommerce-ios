import Foundation
import Yosemite
import Storage
import Tools

/// Settings for the selected Site
///
final class SelectedSiteSettings: NSObject {
    private let stores: StoresManager
    private let storageManager: StorageManagerType

    /// ResultsController: Whenever settings change, I will change. We both change. The world changes.
    ///
    private lazy var resultsController: ResultsController<StorageSiteSetting> = {
        let descriptor = NSSortDescriptor(keyPath: \StorageSiteSetting.siteID, ascending: false)
        return ResultsController<StorageSiteSetting>(storageManager: storageManager, sortedBy: [descriptor])
    }()

    public private(set) var siteSettings: [Yosemite.SiteSetting] = []

    init(stores: StoresManager = ServiceLocator.stores, storageManager: StorageManagerType = ServiceLocator.storageManager) {
        self.stores = stores
        self.storageManager = storageManager
        super.init()
        configureResultsController()
    }
}

// MARK: - ResultsController
//
extension SelectedSiteSettings {

    /// Refreshes the currency settings for the current default site
    ///
    func refresh() {
        refreshResultsPredicate()
    }

    /// Setup: ResultsController
    ///
    private func configureResultsController() {
        resultsController.onDidChangeObject = { [weak self] (object, indexPath, type, newIndexPath) in
            guard let self = self else { return }
            ServiceLocator.currencySettings.updateCurrencyOptions(with: object)
            self.siteSettings = self.resultsController.fetchedObjects
        }
        refreshResultsPredicate()
    }

    private func refreshResultsPredicate() {
        guard let siteID = stores.sessionManager.defaultStoreID else {
            DDLogError("Error: no siteID found when attempting to refresh CurrencySettings results predicate.")
            return
        }

        let sitePredicate = NSPredicate(format: "siteID == %lld", siteID)
        let settingTypePredicate = NSPredicate(format: "settingGroupKey ==[c] %@", SiteSettingGroup.general.rawValue)
        resultsController.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [sitePredicate, settingTypePredicate])
        try? resultsController.performFetch()
        let fetchedObjects = resultsController.fetchedObjects
        siteSettings = fetchedObjects
        fetchedObjects.forEach {
            ServiceLocator.currencySettings.updateCurrencyOptions(with: $0)
        }
    }
}

extension CurrencySettings {
    /// Convenience Initializer:
    /// This is the preferred way to create an instance with the settings coming from the site.
    ///
    public convenience init(siteSettings: [Yosemite.SiteSetting]) {
        self.init()

        siteSettings.forEach { updateCurrencyOptions(with: $0) }
    }

    public func updateCurrencyOptions(with siteSetting: Yosemite.SiteSetting) {
        let value = siteSetting.value

        switch siteSetting.settingID {
        case Constants.currencyCodeKey:
            let currencyCode = CurrencyCode(rawValue: value) ?? CurrencySettings.Default.code
            self.currencyCode = currencyCode
        case Constants.currencyPositionKey:
            let currencyPosition = CurrencyPosition(rawValue: value) ?? CurrencySettings.Default.position
            self.currencyPosition = currencyPosition
        case Constants.thousandSeparatorKey:
            self.thousandSeparator = value
        case Constants.decimalSeparatorKey:
            self.decimalSeparator = value
        case Constants.numberOfDecimalsKey:
            let numberOfDecimals = Int(value) ?? CurrencySettings.Default.decimalPosition
            self.numberOfDecimals = numberOfDecimals
        default:
            break
        }
    }
}
