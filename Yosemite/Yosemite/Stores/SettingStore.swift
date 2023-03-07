import Foundation
import Networking
import Storage


// MARK: - SettingStore
//
public class SettingStore: Store {
    private let siteSettingsRemote: SiteSettingsRemote
    private let siteAPIRemote: SiteAPIRemote

    private lazy var sharedDerivedStorage: StorageType = {
        return storageManager.writerDerivedStorage
    }()

    public override init(dispatcher: Dispatcher, storageManager: StorageManagerType, network: Network) {
        self.siteSettingsRemote = SiteSettingsRemote(network: network)
        self.siteAPIRemote = SiteAPIRemote(network: network)
        super.init(dispatcher: dispatcher, storageManager: storageManager, network: network)
    }

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: SettingAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? SettingAction else {
            assertionFailure("SettingStore received an unsupported action")
            return
        }

        switch action {
        case .synchronizeGeneralSiteSettings(let siteID, let onCompletion):
            synchronizeGeneralSiteSettings(siteID: siteID, onCompletion: onCompletion)
        case .synchronizeProductSiteSettings(let siteID, let onCompletion):
            synchronizeProductSiteSettings(siteID: siteID, onCompletion: onCompletion)
        case .retrieveSiteAPI(let siteID, let onCompletion):
            retrieveSiteAPI(siteID: siteID, onCompletion: onCompletion)
        case let .retrieveCouponSetting(siteID, onCompletion):
            retrieveCouponSetting(siteID: siteID, onCompletion: onCompletion)
        case let .enableCouponSetting(siteID, onCompletion):
            enableCouponSetting(siteID: siteID, onCompletion: onCompletion)
        case let .retrieveAnalyticsSetting(siteID, onCompletion):
            retrieveAnalyticsSetting(siteID: siteID, onCompletion: onCompletion)
        case let .enableAnalyticsSetting(siteID, onCompletion):
            enableAnalyticsSetting(siteID: siteID, onCompletion: onCompletion)
        }
    }
}


// MARK: - Services!
//
private extension SettingStore {

    /// Synchronizes the general site settings associated with the provided Site ID (if any!).
    ///
    func synchronizeGeneralSiteSettings(siteID: Int64, onCompletion: @escaping (Error?) -> Void) {
        siteSettingsRemote.loadGeneralSettings(for: siteID) { [weak self] (settings, error) in
            guard let settings = settings else {
                onCompletion(error)
                return
            }

            self?.upsertStoredGeneralSettingsInBackground(siteID: siteID, readOnlySiteSettings: settings) {
                onCompletion(nil)
            }
        }
    }

    /// Synchronizes the product site settings associated with the provided Site ID (if any!).
    ///
    func synchronizeProductSiteSettings(siteID: Int64, onCompletion: @escaping (Error?) -> Void) {
        siteSettingsRemote.loadProductSettings(for: siteID) { [weak self] (settings, error) in
            guard let settings = settings else {
                onCompletion(error)
                return
            }

            self?.upsertStoredProductSettingsInBackground(siteID: siteID, readOnlySiteSettings: settings) {
                onCompletion(nil)
            }
        }
    }

    /// Retrieves the site API information associated with the provided Site ID (if any!).
    /// This call does NOT persist returned data into the Storage layer.
    ///
    func retrieveSiteAPI(siteID: Int64, onCompletion: @escaping (Result<SiteAPI, Error>) -> Void) {
        siteAPIRemote.loadAPIInformation(for: siteID, completion: onCompletion)
    }

    /// Retrieves the setting for whether coupons are enabled for the specified store
    ///
    func retrieveCouponSetting(siteID: Int64, onCompletion: @escaping (Result<Bool, Error>) -> Void) {
        siteSettingsRemote.loadSetting(for: siteID, settingGroup: .general, settingID: SettingKeys.coupons) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let setting):
                self.upsertStoredGeneralSettingsInBackground(siteID: siteID, readOnlySiteSettings: [setting]) {
                    let isEnabled = setting.value == SettingValue.yes
                    onCompletion(.success(isEnabled))
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }

    /// Enables coupons for the specified store
    ///
    func enableCouponSetting(siteID: Int64, onCompletion: @escaping (Result<Void, Error>) -> Void) {
        siteSettingsRemote.updateSetting(for: siteID, settingGroup: .general, settingID: SettingKeys.coupons, value: SettingValue.yes) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let setting):
                self.upsertStoredGeneralSettingsInBackground(siteID: siteID, readOnlySiteSettings: [setting]) {
                    onCompletion(.success(Void()))
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }

    /// Retrieves the setting for whether WC Analytics are enabled for the specified store
    ///
    func retrieveAnalyticsSetting(siteID: Int64, onCompletion: @escaping (Result<Bool, Error>) -> Void) {
        siteSettingsRemote.loadSetting(for: siteID, settingGroup: .advanced, settingID: SettingKeys.analytics) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let setting):
                self.upsertStoredAdvancedSettingsInBackground(siteID: siteID, readOnlySiteSettings: [setting]) {
                    let isEnabled = setting.value == SettingValue.yes
                    onCompletion(.success(isEnabled))
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }

    /// Enables WC Analytics for the specified store
    ///
    func enableAnalyticsSetting(siteID: Int64, onCompletion: @escaping (Result<Void, Error>) -> Void) {
        siteSettingsRemote.updateSetting(for: siteID,
                                            settingGroup: .advanced,
                                            settingID: SettingKeys.analytics,
                                            value: SettingValue.yes) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let setting):
                self.upsertStoredAdvancedSettingsInBackground(siteID: siteID, readOnlySiteSettings: [setting]) {
                    onCompletion(.success(Void()))
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }
}


// MARK: - Persistence
//
private extension SettingStore {

    /// Updates (OR Inserts) the specified **general** ReadOnly `SiteSetting` Entities **in a background thread**. `onCompletion` will be called
    /// on the main thread!
    ///
    func upsertStoredGeneralSettingsInBackground(siteID: Int64, readOnlySiteSettings: [Networking.SiteSetting], onCompletion: @escaping () -> Void) {
        let derivedStorage = sharedDerivedStorage
        derivedStorage.perform {
            self.upsertSettings(readOnlySiteSettings, in: derivedStorage, siteID: siteID, settingGroup: SiteSettingGroup.general)
        }

        storageManager.saveDerivedType(derivedStorage: derivedStorage) {
            DispatchQueue.main.async(execute: onCompletion)
        }
    }

    /// Updates (OR Inserts) the specified **product** ReadOnly `SiteSetting` entities **in a background thread**. `onCompletion` will be called
    /// on the main thread!
    ///
    func upsertStoredProductSettingsInBackground(siteID: Int64, readOnlySiteSettings: [Networking.SiteSetting], onCompletion: @escaping () -> Void) {
        let derivedStorage = sharedDerivedStorage
        derivedStorage.perform {
            self.upsertSettings(readOnlySiteSettings, in: derivedStorage, siteID: siteID, settingGroup: SiteSettingGroup.product)
        }

        storageManager.saveDerivedType(derivedStorage: derivedStorage) {
            DispatchQueue.main.async(execute: onCompletion)
        }
    }

    /// Updates (OR Inserts) the specified **advanced** ReadOnly `SiteSetting` entities **in a background thread**. `onCompletion` will be called
    /// on the main thread!
    ///
    func upsertStoredAdvancedSettingsInBackground(siteID: Int64, readOnlySiteSettings: [Networking.SiteSetting], onCompletion: @escaping () -> Void) {
        let derivedStorage = sharedDerivedStorage
        derivedStorage.perform {
            self.upsertSettings(readOnlySiteSettings, in: derivedStorage, siteID: siteID, settingGroup: SiteSettingGroup.advanced)
        }

        storageManager.saveDerivedType(derivedStorage: derivedStorage) {
            DispatchQueue.main.async(execute: onCompletion)
        }
    }

    func upsertSettings(_ readOnlySiteSettings: [SiteSetting], in storage: StorageType, siteID: Int64, settingGroup: SiteSettingGroup) {
        // Upsert the settings from the read-only site settings
        for readOnlyItem in readOnlySiteSettings {
            if let existingStorageItem = storage.loadSiteSetting(siteID: siteID, settingID: readOnlyItem.settingID) {
                existingStorageItem.update(with: readOnlyItem)
            } else {
                let newStorageItem = storage.insertNewObject(ofType: Storage.SiteSetting.self)
                newStorageItem.update(with: readOnlyItem)
            }
        }

        // Now, remove any objects that exist in storageSiteSettings but not in readOnlySiteSettings
        if let storageSiteSettings = storage.loadSiteSettings(siteID: siteID, settingGroupKey: settingGroup.rawValue) {
            storageSiteSettings.forEach({ storageItem in
                if readOnlySiteSettings.first(where: { $0.settingID == storageItem.settingID } ) == nil {
                    storage.deleteObject(storageItem)
                }
            })
        }
    }
}


// MARK: - Unit Testing Helpers
//
extension SettingStore {

    /// Unit Testing Helper: Updates or Inserts the specified **general** ReadOnly SiteSetting entities in the provided Storage instance.
    ///
    func upsertStoredGeneralSiteSettings(siteID: Int64, readOnlySiteSettings: [Networking.SiteSetting], in storage: StorageType) {
        upsertSettings(readOnlySiteSettings, in: storage, siteID: siteID, settingGroup: SiteSettingGroup.general)
    }

    /// Unit Testing Helper: Updates or Inserts the specified **product** ReadOnly SiteSetting entities in the provided Storage instance.
    ///
    func upsertStoredProductSiteSettings(siteID: Int64, readOnlySiteSettings: [Networking.SiteSetting], in storage: StorageType) {
        upsertSettings(readOnlySiteSettings, in: storage, siteID: siteID, settingGroup: SiteSettingGroup.product)
    }
}

// MARK: Definitions
extension SettingStore {
    /// Settings keys.
    ///
    private enum SettingKeys {
        static let coupons = "woocommerce_enable_coupons"
        static let analytics = "woocommerce_analytics_enabled"
    }

    private enum SettingValue {
        static let yes = "yes"
    }
}
