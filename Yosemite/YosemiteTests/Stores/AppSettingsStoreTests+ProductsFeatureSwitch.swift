import XCTest

@testable import Yosemite
@testable import Storage

final class AppSettingsStoreTests_ProductsFeatureSwitch: XCTestCase {

    /// Mock Dispatcher!
    ///
    private var dispatcher: Dispatcher!

    /// Mock Storage: InMemory
    ///
    private var storageManager: MockStorageManager!

    /// Mock File Storage: Load data in memory
    ///
    private var fileStorage: MockInMemoryStorage!

    /// Mock General Settings Storage: Load data in memory
    ///
    private var generalAppSettings: GeneralAppSettingsStorage!

    /// Test subject
    ///
    private var subject: AppSettingsStore!

    // Previous feature switch file URL
    private lazy var productsFeatureSwitchURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent("products-feature-switch.plist")
    }()

    // Current feature switch file URL
    private lazy var productsRelease4FeatureSwitchURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent("products-m4-feature-switch.plist")
    }()

    override func setUp() {
        super.setUp()
        dispatcher = Dispatcher()
        storageManager = MockStorageManager()
        fileStorage = MockInMemoryStorage()
        generalAppSettings = GeneralAppSettingsStorage(fileStorage: fileStorage)
        subject = AppSettingsStore(dispatcher: dispatcher, storageManager: storageManager, fileStorage: fileStorage, generalAppSettings: generalAppSettings)
    }

    override func tearDown() {
        dispatcher = nil
        storageManager = nil
        fileStorage = nil
        generalAppSettings = nil
        subject = nil
        super.tearDown()
    }
}
