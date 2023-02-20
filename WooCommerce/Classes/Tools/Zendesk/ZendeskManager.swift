import Foundation
#if !targetEnvironment(macCatalyst)
import SupportSDK
import ZendeskCoreSDK
import CommonUISDK // Zendesk UI SDK
#endif
import WordPressShared
import CoreTelephony
import SafariServices
import Yosemite
import Experiments

extension NSNotification.Name {
    static let ZDPNReceived = NSNotification.Name(rawValue: "ZDPNReceived")
    static let ZDPNCleared = NSNotification.Name(rawValue: "ZDPNCleared")
}

/// Defines methods for showing Zendesk UI.
///
/// This is primarily used for testability. Not all methods in `ZendeskManager` are defined but
/// feel free to add them when needed.
///
protocol ZendeskManagerProtocol: SupportManagerAdapter {
    typealias onUserInformationCompletion = (_ success: Bool, _ email: String?) -> Void

    func observeStoreSwitch()

    /// Displays the Zendesk New Request view from the given controller, for users to submit new tickets.
    ///
    func showNewRequestIfPossible(from controller: UIViewController, with sourceTag: String?)
    func showNewRequestIfPossible(from controller: UIViewController)

    /// Displays a Zendesk New Request view from the given controller, tagged to show in the WCPay queues, for users to submit new tickets.
    ///
    func showNewWCPayRequestIfPossible(from controller: UIViewController, with sourceTag: String?)
    func showNewWCPayRequestIfPossible(from controller: UIViewController)

    /// Creates a Zendesk Identity to be able to submit support request tickets.
    /// Uses the provided `ViewController` to present an alert for requesting email address when required.
    ///
    func createIdentity(presentIn viewController: UIViewController, completion: @escaping (Bool) -> Void)

    /// Creates a support request using the API-Providers SDK.
    ///
    func createSupportRequest(formID: Int64,
                              customFields: [Int64: String],
                              tags: [String],
                              subject: String,
                              description: String,
                              onCompletion: @escaping (Result<Void, Error>) -> Void)

    var zendeskEnabled: Bool { get }
    func userSupportEmail() -> String?
    func showHelpCenter(from controller: UIViewController)
    func showTicketListIfPossible(from controller: UIViewController, with sourceTag: String?)
    func showTicketListIfPossible(from controller: UIViewController)
    func showSupportEmailPrompt(from controller: UIViewController, completion: @escaping onUserInformationCompletion)
    func getTags(supportSourceTag: String?) -> [String]
    func fetchSystemStatusReport()
    func initialize()
    func reset()

    /// To Refactor: These methods would end-up living outside this class. Exposing them here temporarily.
    /// https://github.com/woocommerce/woocommerce-ios/issues/8795
    ///
    func formID() -> Int64
    func wcPayFormID() -> Int64

    func generalTags() -> [String]
    func wcPayTags() -> [String]

    func generalCustomFields() -> [Int64: String]
    func wcPayCustomFields() -> [Int64: String]
}

struct NoZendeskManager: ZendeskManagerProtocol {
    func observeStoreSwitch() {
        // no-op
    }

    func showNewRequestIfPossible(from controller: UIViewController) {
        // no-op
    }

    func showNewWCPayRequestIfPossible(from controller: UIViewController) {
        // no-op
    }

    func showNewRequestIfPossible(from controller: UIViewController, with sourceTag: String?) {
        // no-op
    }

    func showNewWCPayRequestIfPossible(from controller: UIViewController, with sourceTag: String?) {
        // no-op
    }

    func createIdentity(presentIn viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        // no-op
    }

    func createSupportRequest(formID: Int64,
                              customFields: [Int64: String],
                              tags: [String],
                              subject: String,
                              description: String,
                              onCompletion: @escaping (Result<Void, Error>) -> Void) {
        // no-op
    }

    var zendeskEnabled = false

    func userSupportEmail() -> String? {
        return nil
    }

    func showHelpCenter(from controller: UIViewController) {
        // no-op
    }

    func showTicketListIfPossible(from controller: UIViewController, with sourceTag: String?) {
        // no-op
    }

    func showTicketListIfPossible(from controller: UIViewController) {
        // no-op
    }

    func showSupportEmailPrompt(from controller: UIViewController, completion: @escaping onUserInformationCompletion) {
        // no-op
    }

    func getTags(supportSourceTag: String?) -> [String] {
        []
    }

    func fetchSystemStatusReport() {
        // no-op
    }

    func initialize() {
        // no-op
    }

    func reset() {
        // no-op
    }
}

/// To Refactor: These methods would end-up living outside this class. Exposing them here temporarily.
/// https://github.com/woocommerce/woocommerce-ios/issues/8795
///
extension NoZendeskManager {
    func formID() -> Int64 {
        .zero
    }

    func wcPayFormID() -> Int64 {
        .zero
    }

    func generalTags() -> [String] {
        []
    }

    func wcPayTags() -> [String] {
        []
    }

    func generalCustomFields() -> [Int64: String] {
        [:]
    }

    func wcPayCustomFields() -> [Int64: String] {
        [:]
    }
}

extension NoZendeskManager: SupportManagerAdapter {
    /// Executed whenever the app receives a Push Notifications Token.
    ///
    func deviceTokenWasReceived(deviceToken: String) {
        // no-op
    }

    /// Executed whenever the app should unregister for Remote Notifications.
    ///
    func unregisterForRemoteNotifications() {
        // no-op
    }

    /// Executed whenever the app receives a Remote Notification.
    ///
    func pushNotificationReceived() {
        // no-op
    }

    /// Executed whenever the a user has tapped on a Remote Notification.
    ///
    func displaySupportRequest(using userInfo: [AnyHashable: Any]) {
        // no-op
    }
}

struct ZendeskProvider {
    /// Shared Instance
    ///
    #if !targetEnvironment(macCatalyst)
    static let shared: ZendeskManagerProtocol = ZendeskManager()
    #else
    static let shared: ZendeskManagerProtocol = NoZendeskManager()
    #endif
}


/// This class provides the functionality to communicate with Zendesk for Help Center and support ticket interaction,
/// as well as displaying views for the Help Center, new tickets, and ticket list.
///
#if !targetEnvironment(macCatalyst)
final class ZendeskManager: NSObject, ZendeskManagerProtocol {
    private let stores = ServiceLocator.stores
    private let storageManager = ServiceLocator.storageManager

    private let isSSRFeatureFlagEnabled = DefaultFeatureFlagService().isFeatureFlagEnabled(.systemStatusReportInSupportRequest)

    /// Controller for fetching site plugins from Storage
    ///
    private lazy var pluginResultsController: ResultsController<StorageSitePlugin> = createPluginResultsController()

    /// Returns a `pluginResultsController` using the latest selected site ID for predicate
    ///
    private func createPluginResultsController() -> ResultsController<StorageSitePlugin> {
        var sitePredicate: NSPredicate? = nil
        if let siteID = stores.sessionManager.defaultSite?.siteID {
            sitePredicate = NSPredicate(format: "siteID == %lld", siteID)
        } else {
            DDLogError("ZendeskManager: No siteID found when attempting to initialize Plugins Results predicate.")
        }

        let pluginStatusDescriptor = [NSSortDescriptor(keyPath: \StorageSitePlugin.status, ascending: true)]

        return ResultsController(storageManager: storageManager,
                                 matching: sitePredicate,
                                 sortedBy: pluginStatusDescriptor)
    }

    func observeStoreSwitch() {
        pluginResultsController = createPluginResultsController()
        do {
            try pluginResultsController.performFetch()
        } catch {
            DDLogError("ZendeskManager: Unable to update plugin results")
        }
    }

    /// List of tags that reflect Stripe and WCPay plugin statuses
    ///
    private var ippPluginStatuses: [String] {
        var ippTags = [PluginStatus]()
        if let stripe = pluginResultsController.fetchedObjects.first(where: { $0.plugin == PluginSlug.stripe }) {
            if stripe.status == .active {
                ippTags.append(.stripeInstalledAndActivated)
            } else if stripe.status == .inactive {
                ippTags.append(.stripeInstalledButNotActivated)
            }
        } else {
            ippTags.append(.stripeNotInstalled)
        }
        if let wcpay = pluginResultsController.fetchedObjects.first(where: { $0.plugin == PluginSlug.wcpay }) {
            if wcpay.status == .active {
                ippTags.append(.wcpayInstalledAndActivated)
            } else if wcpay.status == .inactive {
                ippTags.append(.wcpayInstalledButNotActivated)
            }
        }
        else {
            ippTags.append(.wcpayNotInstalled)
        }
        return ippTags.map { $0.rawValue }
    }

    /// Instantiates the SystemStatusReportViewModel as soon as the Zendesk instance needs it
    /// This generally happens in the SettingsViewModel if we need to fetch the site's System Status Report
    ///
    private lazy var systemStatusReportViewModel: SystemStatusReportViewModel = SystemStatusReportViewModel(
        siteID: ServiceLocator.stores.sessionManager.defaultSite?.siteID ?? 0
    )

    /// Formatted system status report to be displayed on-screen
    ///
    private var systemStatusReport: String {
        systemStatusReportViewModel.statusReport
    }

    /// Handles fetching the site's System Status Report
    ///
    func fetchSystemStatusReport() {
        systemStatusReportViewModel.fetchReport()
    }

    func showNewRequestIfPossible(from controller: UIViewController) {
        showNewRequestIfPossible(from: controller, with: nil)
    }

    func showNewWCPayRequestIfPossible(from controller: UIViewController) {
        showNewWCPayRequestIfPossible(from: controller, with: nil)
    }

    func showTicketListIfPossible(from controller: UIViewController) {
        showTicketListIfPossible(from: controller, with: nil)
    }

    /// Indicates if Zendesk is Enabled (or not)
    ///
    private (set) var zendeskEnabled = false {
        didSet {
            DDLogInfo("Zendesk Enabled: \(zendeskEnabled)")
        }
    }

    private var unreadNotificationsCount = 0

    var showSupportNotificationIndicator: Bool {
        return unreadNotificationsCount > 0
    }


    // MARK: - Private Properties
    //
    private var deviceToken: String?
    private var userName: String?
    private var userEmail: String?
    private var haveUserIdentity = false
    private var alertNameField: UITextField?

    private weak var presentInController: UIViewController?

    /// Returns a ZendeskPushProvider Instance (If Possible)
    ///
    private var zendeskPushProvider: ZDKPushProvider? {
        guard let zendesk = Zendesk.instance else {
            return nil
        }

        return ZDKPushProvider(zendesk: zendesk)
    }

    /// Designated Initialier
    ///
    fileprivate override init() {
        super.init()
        do {
            try pluginResultsController.performFetch()
        } catch {
            DDLogError("⛔️ Unable to fetch plugins from storage: \(error)")
        }
        observeZendeskNotifications()
    }


    // MARK: - Public Methods


    /// Sets up the Zendesk Manager instance
    ///
    func initialize() {
        guard zendeskEnabled == false else {
            DDLogError("☎️ Zendesk was already Initialized!")
            return
        }

        Zendesk.initialize(appId: ApiCredentials.zendeskAppId,
                           clientId: ApiCredentials.zendeskClientId,
                           zendeskUrl: ApiCredentials.zendeskUrl)
        Support.initialize(withZendesk: Zendesk.instance)
        CommonTheme.currentTheme.primaryColor = UIColor.primary

        haveUserIdentity = getUserProfile()
        zendeskEnabled = true
    }

    /// Deletes all known user default keys
    ///
    func reset() {
        removeUserProfile()
        removeUnreadCount()
    }


    // MARK: - Show Zendesk Views
    //
    // -TODO: in the future this should show the Zendesk Help Center.
    /// For now, link to the online help documentation
    ///
    func showHelpCenter(from controller: UIViewController) {
        WebviewHelper.launch(WooConstants.URLs.helpCenter.asURL(), with: controller)

        ServiceLocator.analytics.track(.supportHelpCenterViewed)
    }

    /// Displays the Zendesk New Request view from the given controller, for users to submit new tickets.
    ///
    func showNewRequestIfPossible(from controller: UIViewController, with sourceTag: String?) {
        createIdentity(presentIn: controller) { success in
            guard success else {
                return
            }

            ServiceLocator.analytics.track(.supportNewRequestViewed)

            let newRequestConfig = self.createRequest(supportSourceTag: sourceTag)
            let newRequestController = RequestUi.buildRequestUi(with: [newRequestConfig])
            self.showZendeskView(newRequestController, from: controller)
        }
    }

    /// Displays a Zendesk New Request view from the given controller, tagged to show in the WCPay queues, for users to submit new tickets.
    ///
    func showNewWCPayRequestIfPossible(from controller: UIViewController, with sourceTag: String?) {
        createIdentity(presentIn: controller) { success in
            guard success else {
                return
            }

            ServiceLocator.analytics.track(.supportNewRequestViewed)

            let newRequestConfig = self.createWCPayRequest(supportSourceTag: sourceTag)
            let newRequestController = RequestUi.buildRequestUi(with: [newRequestConfig])
            self.showZendeskView(newRequestController, from: controller)
        }
    }

    /// Creates a Zendesk Identity to be able to submit support request tickets.
    /// Uses the provided `ViewController` to present an alert for requesting email address when required.
    ///
    func createIdentity(presentIn viewController: UIViewController, completion: @escaping (Bool) -> Void) {

        // If we already have an identity, do nothing.
        guard haveUserIdentity == false else {
            DDLogDebug("Using existing Zendesk identity: \(userEmail ?? ""), \(userName ?? "")")
            registerDeviceTokenIfNeeded()
            completion(true)
            return
        }

        /*
         1. Attempt to get user information from User Defaults.
         2. If we don't have the user's information yet, attempt to get it from the account/site.
         3. Prompt the user for email & name, pre-populating with user information obtained in step 1.
         4. Create Zendesk identity with user information.
         */

        if getUserProfile() {
            createZendeskIdentity { success in
                guard success else {
                    DDLogInfo("Creating Zendesk identity failed.")
                    completion(false)
                    return
                }
                DDLogDebug("Using User Defaults for Zendesk identity.")
                self.haveUserIdentity = true
                self.registerDeviceTokenIfNeeded()
                completion(true)
                return
            }
        }

        getUserInformationAndShowPrompt(withName: true, from: viewController) { (success, _) in
            if success {
                self.registerDeviceTokenIfNeeded()
            }

            completion(success)
        }
    }

    /// Creates a support request using the API-Providers SDK.
    ///
    func createSupportRequest(formID: Int64,
                              customFields: [Int64: String],
                              tags: [String],
                              subject: String,
                              description: String,
                              onCompletion: @escaping (Result<Void, Error>) -> Void) {

        let requestProvider = ZDKRequestProvider()
        let request = createAPIRequest(formID: formID, customFields: customFields, tags: tags, subject: subject, description: description)
        requestProvider.createRequest(request) { _, error in
            // `requestProvider.createRequest` invokes it's completion block on a background thread when the request creation fails.
            // Lets make sure we always dispatch the completion block on the main queue.
            DispatchQueue.main.async {
                if let error {
                    return onCompletion(.failure(error))
                }
                onCompletion(.success(()))
            }
        }
    }

    /// Displays the Zendesk Request List view from the given controller, allowing user to access their tickets.
    ///
    func showTicketListIfPossible(from controller: UIViewController, with sourceTag: String?) {

        createIdentity(presentIn: controller) { success in
            guard success else {
                return
            }

            ServiceLocator.analytics.track(.supportTicketListViewed)

            let requestConfig = self.createRequest(supportSourceTag: sourceTag)
            let requestListController = RequestUi.buildRequestList(with: [requestConfig])
            self.showZendeskView(requestListController, from: controller)
        }
    }

    /// Displays a single ticket's view if possible.
    ///
    func showSingleTicketViewIfPossible(for requestId: String, from navController: UINavigationController) {
        let requestConfig = self.createRequest(supportSourceTag: nil)
        let requestController = RequestUi.buildRequestUi(requestId: requestId, configurations: [requestConfig])

        showZendeskView(requestController, from: navController)
    }

    /// Displays an alert allowing the user to change their Support email address.
    ///
    func showSupportEmailPrompt(from controller: UIViewController, completion: @escaping onUserInformationCompletion) {
        ServiceLocator.analytics.track(.supportIdentityFormViewed)
        presentInController = controller

        // If the user hasn't already set a username, go ahead and ask for that too.
        var withName = true
        if let name = userName, !name.isEmpty {
            withName = false
        }

        getUserInformationAndShowPrompt(withName: withName, from: controller) { (success, email) in
            completion(success, email)
        }
    }


    // MARK: - Helpers

    /// Returns the user's Support email address.
    ///
    func userSupportEmail() -> String? {
        let _ = getUserProfile()
        return userEmail
    }

    /// Returns the tags for the ZD ticket field.
    /// Tags are used for refining and filtering tickets so they display in the web portal, under "Lovely Views".
    /// The SDK tag is used in a trigger and displays tickets in Woo > Mobile Apps New.
    ///
    func getTags(supportSourceTag: String?) -> [String] {
        let tags = [Constants.platformTag, Constants.sdkTag, Constants.jetpackTag] + ippPluginStatuses
        return decorateTags(tags: tags, supportSourceTag: supportSourceTag)
    }

    func getWCPayTags(supportSourceTag: String?) -> [String] {
        let tags = [Constants.platformTag,
                    Constants.sdkTag,
                    Constants.paymentsProduct,
                    Constants.paymentsCategory,
                    Constants.paymentsSubcategory,
                    Constants.paymentsProductArea]

        return decorateTags(tags: tags, supportSourceTag: supportSourceTag)
    }

    func decorateTags(tags: [String], supportSourceTag: String?) -> [String] {
        guard let site = ServiceLocator.stores.sessionManager.defaultSite else {
            return tags
        }

        var decoratedTags = tags

        if site.isWordPressComStore == true {
            decoratedTags.append(Constants.wpComTag)
        }

        if site.plan.isEmpty == false {
            decoratedTags.append(site.plan)
        }

        if let sourceTagOrigin = supportSourceTag, sourceTagOrigin.isEmpty == false {
            decoratedTags.append(sourceTagOrigin)
        }

        if ServiceLocator.stores.isAuthenticatedWithoutWPCom {
            decoratedTags.append(Constants.authenticatedWithApplicationPasswordTag)
        }

        return decoratedTags
    }
}

/// To Refactor: These methods would end-up living outside this class. Exposing them here temporarily.
/// https://github.com/woocommerce/woocommerce-ios/issues/8795
///
extension ZendeskManager {
    func formID() -> Int64 {
        TicketFieldIDs.form
    }

    func wcPayFormID() -> Int64 {
        TicketFieldIDs.paymentsForm
    }

    func generalTags() -> [String] {
        getTags(supportSourceTag: nil)
    }

    func wcPayTags() -> [String] {
        getWCPayTags(supportSourceTag: nil)
    }

    func generalCustomFields() -> [Int64: String] {
        // Extracts the custom fields from the `createRequest` method
        createRequest(supportSourceTag: nil).customFields.reduce([:]) { dict, field in
            guard let value = field.value as? String else { return dict } // Guards that all values are string
            var mutableDict = dict
            mutableDict[field.fieldId] = value
            return mutableDict
        }
    }

    func wcPayCustomFields() -> [Int64: String] {
        // Extracts the custom fields from the `createWCPayRequest` method.
        createWCPayRequest(supportSourceTag: nil).customFields.reduce([:]) { dict, field in
            guard let value = field.value as? String else { return dict } // Guards that all values are string
            var mutableDict = dict
            mutableDict[field.fieldId] = value
            return mutableDict
        }
    }
}

// MARK: - Push Notifications
//
extension ZendeskManager {
    /// Registers the last known DeviceToken in the Zendesk Backend (if any).
    ///
    func registerDeviceTokenIfNeeded() {
        guard let deviceToken = deviceToken else {
            DDLogError("☎️ [Zendesk] Missing Device Token!")
            return
        }

        registerDeviceToken(deviceToken)
    }

    /// Registers the specified DeviceToken in the Zendesk Backend (if possible).
    ///
    func registerDeviceToken(_ deviceToken: String) {
        DDLogInfo("☎️ [Zendesk] Registering Device Token...")
        zendeskPushProvider?.register(deviceIdentifier: deviceToken, locale: Locale.preferredLanguage) { (_, error) in
            if let error = error {
                DDLogError("☎️ [Zendesk] Couldn't register Device Token [\(deviceToken)]. Error: \(error)")
                return
            }

            DDLogInfo("☎️ [Zendesk] Successfully registered Device Token: [\(deviceToken)]")
        }
    }

    func postNotificationReceived() {
        // Updating unread indicators should trigger UI updates, so send notification in main thread.
        DispatchQueue.main.async {
           NotificationCenter.default.post(name: .ZDPNReceived, object: nil)
        }
    }

    func postNotificationRead() {
        // Updating unread indicators should trigger UI updates, so send notification in main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ZDPNCleared, object: nil)
        }
    }
}


// MARK: - ZendeskManager: SupportManagerAdapter Conformance
//
extension ZendeskManager: SupportManagerAdapter {
    /// Stores the DeviceToken. Zendesk doesn't allow us to register for APNS until an Identity has been created.
    ///
    func deviceTokenWasReceived(deviceToken: String) {
        self.deviceToken = deviceToken
    }

    /// Unregisters from the Zendesk Push Notifications Service.
    ///
    func unregisterForRemoteNotifications() {
        DDLogInfo("☎️ [Zendesk] Unregistering for Notifications...")
        zendeskPushProvider?.unregisterForPush()
    }

    /// This handles Zendesk push notifications.
    ///
    func displaySupportRequest(using userInfo: [AnyHashable: Any]) {

        // Prevent navigating to an individual ticker from a push notification as we won't support viewing individual tickets on the new Support Form.
        if ServiceLocator.featureFlagService.isFeatureFlagEnabled(.supportRequests) {
            return
        }

        guard zendeskEnabled == true,
            let requestId = userInfo[PushKey.requestID] as? String else {
                DDLogInfo("Zendesk push notification payload is invalid.")
                return
        }

        // grab the tab bar
        guard let tabBar = AppDelegate.shared.tabBarController else {
            return
        }

        // select My Store
        tabBar.navigateTo(.myStore)

        // store the navController
        guard let navController = tabBar.selectedViewController as? UINavigationController else {
            DDLogError("⛔️ Unable to navigate to Zendesk deep link. Failed to find a nav controller.")
            return
        }

        // navigate thru the stack
        let dashboard = UIStoryboard.dashboard
        let settingsID = SettingsViewController.classNameWithoutNamespaces
        let settingsVC = dashboard.instantiateViewController(withIdentifier: settingsID) as! SettingsViewController
        navController.pushViewController(settingsVC, animated: false)

        let helpID = HelpAndSupportViewController.classNameWithoutNamespaces
        let helpAndSupportVC = dashboard.instantiateViewController(withIdentifier: helpID) as! HelpAndSupportViewController
        navController.pushViewController(helpAndSupportVC, animated: false)

        // show the single ticket view instead of the ticket list
        showSingleTicketViewIfPossible(for: requestId, from: navController)
    }

    /// Delegate method for a received push notification
    ///
    func pushNotificationReceived() {
        // Do not update the notification count when the new SupportForm is enabled
        // because we can't clear it back as we won't allow navigating to individual tickets.
        if ServiceLocator.featureFlagService.isFeatureFlagEnabled(.supportRequests) {
            return
        }

        unreadNotificationsCount += 1
        saveUnreadCount()
        postNotificationReceived()
    }
}


// MARK: - Private Extension
//
private extension ZendeskManager {

    func getUserInformationAndShowPrompt(withName: Bool, from viewController: UIViewController, completion: @escaping onUserInformationCompletion) {
        presentInController = viewController
        getUserInformationIfAvailable()
        promptUserForInformation(withName: withName, from: viewController) { (success, email) in
            guard success else {
                DDLogInfo("No user information to create Zendesk identity with.")
                completion(false, nil)
                return
            }

            self.createZendeskIdentity { success in
                guard success else {
                    DDLogInfo("Creating Zendesk identity failed.")
                    completion(false, nil)
                    return
                }

                DDLogDebug("Using information from prompt for Zendesk identity.")
                self.haveUserIdentity = true
                completion(true, email)
                return
            }
        }
    }

    func getUserInformationIfAvailable() {
        userEmail = ServiceLocator.stores.sessionManager.defaultAccount?.email
        userName = ServiceLocator.stores.sessionManager.defaultAccount?.username

        if let displayName = ServiceLocator.stores.sessionManager.defaultAccount?.displayName,
            !displayName.isEmpty {
            userName = displayName
        }
    }

    func createZendeskIdentity(completion: @escaping (Bool) -> Void) {

        guard let userEmail = userEmail else {
            DDLogInfo("No user email to create Zendesk identity with.")
            let identity = Identity.createAnonymous()
            Zendesk.instance?.setIdentity(identity)
            completion(false)

            return
        }

        let zendeskIdentity = Identity.createAnonymous(name: userName, email: userEmail)
        Zendesk.instance?.setIdentity(zendeskIdentity)

        DDLogDebug("Zendesk identity created with email '\(userEmail)' and name '\(userName ?? "")'.")
        completion(true)
    }


    // MARK: - Request Controller Configuration

    /// Important: Any time a new request controller is created, these configurations should be attached.
    /// Without it, the tickets won't appear in the correct view(s) in the web portal and they won't contain all the metadata needed to solve a ticket.
    ///
    func createRequest(supportSourceTag: String?) -> RequestUiConfiguration {

        var logsFieldID: Int64 = TicketFieldIDs.legacyLogs
        var systemStatusReportFieldID: Int64 = 0
        if isSSRFeatureFlagEnabled {
            /// If the feature flag is enabled, `legacyLogs` Field ID is used to send the SSR logs,
            /// and `logs` Field ID is used to send the logs.
            ///
            logsFieldID = TicketFieldIDs.logs
            systemStatusReportFieldID = TicketFieldIDs.legacyLogs
        }

        let ticketFields = [
            CustomField(fieldId: TicketFieldIDs.appVersion, value: Bundle.main.version),
            CustomField(fieldId: TicketFieldIDs.deviceFreeSpace, value: getDeviceFreeSpace()),
            CustomField(fieldId: TicketFieldIDs.networkInformation, value: getNetworkInformation()),
            CustomField(fieldId: logsFieldID, value: getLogFile()),
            CustomField(fieldId: systemStatusReportFieldID, value: systemStatusReport),
            CustomField(fieldId: TicketFieldIDs.currentSite, value: getCurrentSiteDescription()),
            CustomField(fieldId: TicketFieldIDs.sourcePlatform, value: Constants.sourcePlatform),
            CustomField(fieldId: TicketFieldIDs.appLanguage, value: Locale.preferredLanguage),
            CustomField(fieldId: TicketFieldIDs.subcategory, value: Constants.subcategory)
        ].compactMap { $0 }

        return createRequest(supportSourceTag: supportSourceTag,
                             formID: TicketFieldIDs.form,
                             ticketFields: ticketFields,
                             tags: getTags(supportSourceTag: supportSourceTag))
    }

    func createWCPayRequest(supportSourceTag: String?) -> RequestUiConfiguration {

        var logsFieldID: Int64 = TicketFieldIDs.legacyLogs
        var systemStatusReportFieldID: Int64 = 0
        if isSSRFeatureFlagEnabled {
            /// If the feature flag is enabled, `legacyLogs` Field ID is used to send the SSR logs,
            /// and `logs` Field ID is used to send the logs.
            ///
            logsFieldID = TicketFieldIDs.logs
            systemStatusReportFieldID = TicketFieldIDs.legacyLogs
        }

        // Set form field values
        let ticketFields = [
            CustomField(fieldId: TicketFieldIDs.appVersion, value: Bundle.main.version),
            CustomField(fieldId: TicketFieldIDs.deviceFreeSpace, value: getDeviceFreeSpace()),
            CustomField(fieldId: TicketFieldIDs.networkInformation, value: getNetworkInformation()),
            CustomField(fieldId: logsFieldID, value: getLogFile()),
            CustomField(fieldId: systemStatusReportFieldID, value: systemStatusReport),
            CustomField(fieldId: TicketFieldIDs.currentSite, value: getCurrentSiteDescription()),
            CustomField(fieldId: TicketFieldIDs.sourcePlatform, value: Constants.sourcePlatform),
            CustomField(fieldId: TicketFieldIDs.appLanguage, value: Locale.preferredLanguage),
            CustomField(fieldId: TicketFieldIDs.category, value: Constants.paymentsCategory),
            CustomField(fieldId: TicketFieldIDs.subcategory, value: Constants.paymentsSubcategory),
        ].compactMap { $0 }

        return createRequest(supportSourceTag: supportSourceTag,
                             formID: TicketFieldIDs.paymentsForm,
                             ticketFields: ticketFields,
                             tags: getWCPayTags(supportSourceTag: supportSourceTag))
    }

    func createRequest(supportSourceTag: String?, formID: Int64, ticketFields: [CustomField], tags: [String]) -> RequestUiConfiguration {
        let requestConfig = RequestUiConfiguration()

        // Set Zendesk ticket form to use
        requestConfig.ticketFormID = formID as NSNumber

        requestConfig.customFields = ticketFields

        // Set tags
        requestConfig.tags = tags

        // Set the ticket subject
        requestConfig.subject = Constants.ticketSubject

        // No extra config needed to attach an image. Hooray!

        return requestConfig
    }

    /// Creates a Zendesk Request to be consumed by a Request Provider.
    ///
    func createAPIRequest(formID: Int64, customFields: [Int64: String], tags: [String], subject: String, description: String) -> ZDKCreateRequest {
        let request = ZDKCreateRequest()
        request.ticketFormId = formID as NSNumber
        request.customFields = customFields.map { CustomField(fieldId: $0, value: $1) }
        request.tags = tags
        request.subject = subject
        request.requestDescription = description
        return request
    }

    // MARK: - View
    //
    func showZendeskView(_ zendeskView: UIViewController, from controller: UIViewController) {
        // Got some duck typing going on in here. Sorry.

        // If the controller is a UIViewController, set the modal display for iPad.
        if !controller.isKind(of: UINavigationController.self) && UIDevice.current.userInterfaceIdiom == .pad {
            presentZendeskViewModally(zendeskView, from: controller)
            return
        }

        if let navController = controller as? UINavigationController {
            navController.pushViewController(zendeskView, animated: true)
            return
        }

        if let navController = controller.navigationController {
            navController.pushViewController(zendeskView, animated: true)
            return
        }

        if let navController = presentInController as? UINavigationController {
            navController.pushViewController(zendeskView, animated: true)
            return
        }

        presentZendeskViewModally(zendeskView, from: controller)
    }

    private func presentZendeskViewModally(_ zendeskView: UIViewController, from controller: UIViewController) {
        let navController = WooNavigationController(rootViewController: zendeskView)
        // Keeping the modal fullscreen on iPad like previous implementation.
        if UIDevice.current.userInterfaceIdiom == .pad {
            navController.modalPresentationStyle = .fullScreen
            navController.modalTransitionStyle = .crossDissolve
        }
        controller.present(navController, animated: true)
    }

    // MARK: - User Defaults
    //
    func saveUserProfile() {
        var userProfile = [String: String]()
        userProfile[Constants.profileEmailKey] = userEmail
        userProfile[Constants.profileNameKey] = userName
        DDLogDebug("Zendesk - saving profile to User Defaults: \(userProfile)")
        UserDefaults.standard.set(userProfile, forKey: Constants.zendeskProfileUDKey)
        UserDefaults.standard.synchronize()
    }

    func getUserProfile() -> Bool {
        guard let userProfile = UserDefaults.standard.dictionary(forKey: Constants.zendeskProfileUDKey) else {
            return false
        }
        DDLogDebug("Zendesk - read profile from User Defaults: \(userProfile)")
        userEmail = userProfile.valueAsString(forKey: Constants.profileEmailKey)
        userName = userProfile.valueAsString(forKey: Constants.profileNameKey)
        return true
    }

    func saveUnreadCount() {
        UserDefaults.standard.set(unreadNotificationsCount, forKey: Constants.unreadNotificationsKey)
    }

    func removeUserProfile() {
        UserDefaults.standard.removeObject(forKey: Constants.zendeskProfileUDKey)
    }

    func removeUnreadCount() {
        UserDefaults.standard.removeObject(forKey: Constants.unreadNotificationsKey)
    }


    // MARK: - Data Helpers
    //
    func getDeviceFreeSpace() -> String {

        guard let resourceValues = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityKey]),
            let capacityBytes = resourceValues.volumeAvailableCapacity else {
                return Constants.unknownValue
        }

        // format string using human readable units. ex: 1.5 GB
        // Since ByteCountFormatter.string translates the string and has no locale setting,
        // do the byte conversion manually so the Free Space is in English.
        let sizeAbbreviations = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        var sizeAbbreviationsIndex = 0
        var capacity = Double(capacityBytes)

        while capacity > 1024 {
            capacity /= 1024
            sizeAbbreviationsIndex += 1
        }

        let formattedCapacity = String(format: "%4.2f", capacity)
        let sizeAbbreviation = sizeAbbreviations[sizeAbbreviationsIndex]
        return "\(formattedCapacity) \(sizeAbbreviation)"
    }

    func getLogFile() -> String {

        guard let logFileInformation = ServiceLocator.fileLogger.logFileManager.sortedLogFileInfos.first,
            let logData = try? Data(contentsOf: URL(fileURLWithPath: logFileInformation.filePath)),
            let logText = String(data: logData, encoding: .utf8) else {
                return ""
        }

        // Truncates the log text so it fits in the ticket field.
        if logText.count > Constants.logFieldCharacterLimit {
            return String(logText.suffix(Constants.logFieldCharacterLimit))
        }

        return logText
    }

    func getCurrentSiteDescription() -> String {
        guard let site = ServiceLocator.stores.sessionManager.defaultSite else {
            return String()
        }

        return "\(site.url) (\(site.description))"
    }


    func getNetworkInformation() -> String {
        let networkType: String = {
            let reachibilityStatus = ZDKReachability.forInternetConnection().currentReachabilityStatus()
            switch reachibilityStatus {
            case .reachableViaWiFi:
                return Constants.networkWiFi
            case .reachableViaWWAN:
                return Constants.networkWWAN
            default:
                return Constants.unknownValue
            }
        }()

        let networkCarrier = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders?.first?.value
        let carrierName = networkCarrier?.carrierName ?? Constants.unknownValue
        let carrierCountryCode = networkCarrier?.isoCountryCode ?? Constants.unknownValue

        let networkInformation = [
            "\(Constants.networkTypeLabel) \(networkType)",
            "\(Constants.networkCarrierLabel) \(carrierName)",
            "\(Constants.networkCountryCodeLabel) \(carrierCountryCode)"
        ]

        return networkInformation.joined(separator: "\n")
    }


    // MARK: - User Information Prompt
    //
    func promptUserForInformation(withName: Bool, from viewController: UIViewController, completion: @escaping onUserInformationCompletion) {

        let alertMessage = withName ? LocalizedText.alertMessageWithName : LocalizedText.alertMessage
        let alertController = UIAlertController(title: nil, message: alertMessage, preferredStyle: .alert)

        // Cancel Action
        alertController.addCancelActionWithTitle(LocalizedText.alertCancel) { _ in
            completion(false, nil)
            return
        }

        // Submit Action
        let submitAction = alertController.addDefaultActionWithTitle(LocalizedText.alertSubmit) { [weak alertController] _ in
            guard let email = alertController?.textFields?.first?.text else {
                completion(false, nil)
                return
            }

            self.userEmail = email

            if withName {
                self.userName = alertController?.textFields?.last?.text
            }

            self.saveUserProfile()
            completion(true, email)
            return
        }

        // Enable Submit based on email validity.
        let email = userEmail ?? ""
        submitAction.isEnabled = EmailFormatValidator.validate(string: email)

        // Make Submit button bold.
        alertController.preferredAction = submitAction

        // Email Text Field
        alertController.addTextField { textField in
            textField.clearButtonMode = .always
            textField.keyboardType = .emailAddress
            textField.placeholder = LocalizedText.emailPlaceholder
            textField.text = self.userEmail

            textField.addTarget(self,
                                action: #selector(self.emailTextFieldDidChange),
                                for: UIControl.Event.editingChanged)
        }

        // Name Text Field
        if withName {
            alertController.addTextField { [weak self] textField in
                guard let self = self else { return }
                textField.clearButtonMode = .always
                textField.placeholder = LocalizedText.namePlaceholder
                textField.text = self.userName
                textField.delegate = self
                self.alertNameField = textField
            }
        }

        // Show alert
        viewController.present(alertController, animated: true, completion: nil)
    }

    /// Uses `@objc` because this method is used in a `#selector()` call
    ///
    @objc func emailTextFieldDidChange(_ textField: UITextField) {
        guard let alertController = presentInController?.presentedViewController as? UIAlertController,
            let email = alertController.textFields?.first?.text,
            let submitAction = alertController.actions.last else {
                return
        }

        submitAction.isEnabled = EmailFormatValidator.validate(string: email)
        updateNameFieldForEmail(email)
    }

    func updateNameFieldForEmail(_ email: String) {
        guard let alertController = presentInController?.presentedViewController as? UIAlertController,
            let totalTextFields = alertController.textFields?.count,
            totalTextFields > 1,
            let nameField = alertController.textFields?.last else {
                return
        }

        guard !email.isEmpty else {
            return
        }

        // If we don't already have the user's name, generate it from the email.
        if userName == nil {
            nameField.text = generateDisplayName(from: email)
        }
    }

    func generateDisplayName(from rawEmail: String) -> String {
        guard rawEmail.isEmpty == false else {
            return ""
        }

        // Generate Name, using the same format as Signup.

        // step 1: lower case
        let email = rawEmail.lowercased()
        // step 2: remove the @ and everything after
        let localPart = email.split(separator: "@")[safe: 0]
        // step 3: remove all non-alpha characters
        let localCleaned = localPart?.replacingOccurrences(of: "[^A-Za-z/.]", with: "", options: .regularExpression)
        // step 4: turn periods into spaces
        let nameLowercased = localCleaned?.replacingOccurrences(of: ".", with: " ")
        // step 5: capitalize
        let autoDisplayName = nameLowercased?.capitalized

        return autoDisplayName ?? ""
    }
}


// MARK: - Notifications
//
private extension ZendeskManager {

    /// Listens to Zendesk Notifications
    ///
    func observeZendeskNotifications() {
        // Ticket Attachments
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_UploadAttachmentSuccess), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_UploadAttachmentError), object: nil)

        // New Ticket Creation
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_RequestSubmissionSuccess), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_RequestSubmissionError), object: nil)

        // Ticket Reply
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_CommentSubmissionSuccess), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_CommentSubmissionError), object: nil)

        // View Ticket List
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_RequestsError), object: nil)

        // View Individual Ticket
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_CommentListSuccess), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZDKAPI_CommentListError), object: nil)

        // Help Center
        NotificationCenter.default.addObserver(self, selector: #selector(zendeskNotification(_:)),
                                               name: NSNotification.Name(rawValue: ZD_HC_SearchSuccess), object: nil)
    }


    /// Handles (all of the) Zendesk Notifications
    ///
    @objc func zendeskNotification(_ notification: Notification) {
        switch notification.name.rawValue {
        case ZDKAPI_RequestSubmissionSuccess where !ServiceLocator.featureFlagService.isFeatureFlagEnabled(.supportRequests):
            ServiceLocator.analytics.track(.supportNewRequestCreated)
        case ZDKAPI_RequestSubmissionError where !ServiceLocator.featureFlagService.isFeatureFlagEnabled(.supportRequests):
            ServiceLocator.analytics.track(.supportNewRequestFailed)
        case ZDKAPI_UploadAttachmentSuccess:
            ServiceLocator.analytics.track(.supportNewRequestFileAttached)
        case ZDKAPI_UploadAttachmentError:
            ServiceLocator.analytics.track(.supportNewRequestFileAttachmentFailed)
        case ZDKAPI_CommentSubmissionSuccess:
            ServiceLocator.analytics.track(.supportTicketUserReplied)
        case ZDKAPI_CommentSubmissionError:
            ServiceLocator.analytics.track(.supportTicketUserReplyFailed)
        case ZDKAPI_RequestsError:
            ServiceLocator.analytics.track(.supportTicketListViewFailed)
        case ZDKAPI_CommentListSuccess:
            ServiceLocator.analytics.track(.supportTicketUserViewed)
        case ZDKAPI_CommentListError:
            ServiceLocator.analytics.track(.supportTicketViewFailed)
        case ZD_HC_SearchSuccess:
            ServiceLocator.analytics.track(.supportHelpCenterUserSearched)
        default:
            break
        }
    }
}


// MARK: - Nested Types
//
private extension ZendeskManager {

    // MARK: - Constants
    //
    struct Constants {
        static let unknownValue = "unknown"
        static let noValue = "none"
        static let mobileCategoryID: UInt64 = 360000041586
        static let articleLabel = "iOS"
        static let platformTag = "iOS"
        static let sdkTag = "woo-mobile-sdk"
        static let ticketSubject = NSLocalizedString(
            "WooCommerce for iOS Support",
            comment: "Subject of new Zendesk ticket."
        )
        static let blogSeperator = "\n----------\n"
        static let jetpackTag = "jetpack"
        static let wpComTag = "wpcom"
        static let authenticatedWithApplicationPasswordTag = "application_password_authenticated"
        static let logFieldCharacterLimit = 64000
        static let networkWiFi = "WiFi"
        static let networkWWAN = "Mobile"
        static let networkTypeLabel = "Network Type:"
        static let networkCarrierLabel = "Carrier:"
        static let networkCountryCodeLabel = "Country Code:"
        static let zendeskProfileUDKey = "wc_zendesk_profile"
        static let profileEmailKey = "email"
        static let profileNameKey = "name"
        static let unreadNotificationsKey = "wc_zendesk_unread_notifications"
        static let nameFieldCharacterLimit = 50
        static let sourcePlatform = "mobile_-_woo_ios"
        static let subcategory = "WooCommerce Mobile Apps"
        static let paymentsCategory = "support"
        static let paymentsSubcategory = "payment"
        static let paymentsProduct = "woocommerce_payments"
        static let paymentsProductArea = "product_area_woo_payment_gateway"
    }

    // Zendesk expects these as NSNumber. However, they are defined as UInt64 to satisfy 32-bit devices (ex: iPhone 5).
    // Which means they then have to be converted to NSNumber when sending to Zendesk.
    struct TicketFieldIDs {
        static let form: Int64 = 360000010286
        static let paymentsForm: Int64 = 189946
        static let paymentsGroup: Int64 = 27709263
        static let appVersion: Int64 = 360000086866
        static let allBlogs: Int64 = 360000087183
        static let deviceFreeSpace: Int64 = 360000089123
        static let networkInformation: Int64 = 360000086966
        static let legacyLogs: Int64 = 22871957
        static let logs: Int64 = 10901699622036
        static let currentSite: Int64 = 360000103103
        static let sourcePlatform: Int64 = 360009311651
        static let appLanguage: Int64 = 360008583691
        static let category: Int64 = 25176003
        static let subcategory: Int64 = 25176023
        static let product: Int64 = 25254766
        static let productArea: Int64 = 360025069951
    }

    struct LocalizedText {
        static let alertMessageWithName = NSLocalizedString(
            "Please enter your email address and username:",
            comment: "Instructions for alert asking for email and name."
        )
        static let alertMessage = NSLocalizedString(
            "Please enter your email address:",
            comment: "Instructions for alert asking for email."
        )
        static let alertSubmit = NSLocalizedString(
            "OK",
            comment: "Submit button on prompt for user information."
        )
        static let alertCancel = NSLocalizedString(
            "Cancel",
            comment: "Cancel prompt for user information."
        )
        static let emailPlaceholder = NSLocalizedString(
            "Email",
            comment: "Email address text field placeholder"
        )
        static let namePlaceholder = NSLocalizedString(
            "Name",
            comment: "Name text field placeholder"
        )
    }

    struct PushKey {
        static let requestID = "zendesk_sdk_request_id"
    }
}

private extension ZendeskManager {
    enum PluginSlug {
        static let stripe = "woocommerce-gateway-stripe/woocommerce-gateway-stripe"
        static let wcpay = "woocommerce-payments/woocommerce-payments"
    }
    enum PluginStatus: String {
        case stripeNotInstalled = "woo_mobile_stripe_not_installed"
        case stripeInstalledAndActivated = "woo_mobile_stripe_installed_and_activated"
        case stripeInstalledButNotActivated = "woo_mobile_stripe_installed_and_not_activated"
        case wcpayNotInstalled = "woo_mobile_wcpay_not_installed"
        case wcpayInstalledAndActivated = "woo_mobile_wcpay_installed_and_activated"
        case wcpayInstalledButNotActivated = "woo_mobile_wcpay_installed_and_not_activated"
    }
}

// MARK: - UITextFieldDelegate
//
extension ZendeskManager: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == alertNameField,
            let text = textField.text else {
                return true
        }

        let newLength = text.count + string.count - range.length
        return newLength <= Constants.nameFieldCharacterLimit
    }
}
#endif
