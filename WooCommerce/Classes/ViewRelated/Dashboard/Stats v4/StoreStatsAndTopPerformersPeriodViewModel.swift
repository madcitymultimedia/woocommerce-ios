import Combine
import Yosemite
import class AutomatticTracks.CrashLogging

/// ViewModel for `StoreStatsAndTopPerformersPeriodViewController`.
///
/// This was created after `StoreStatsAndTopPerformersPeriodViewController` existed so not
/// all data-loading are in here.
///
final class StoreStatsAndTopPerformersPeriodViewModel {

    /// If applicable, present the in-app feedback card. The in-app feedback card may still not be
    /// presented depending on the constraints. But setting this to `false`, will ensure that it
    /// will never be presented.
    let canDisplayInAppFeedbackCard: Bool

    /// An Observable that informs the UI whether the in-app feedback card should be displayed or not.
    @Published private(set) var isInAppFeedbackCardVisible: Bool = false

    private let storesManager: StoresManager
    private let analytics: Analytics

    /// Create an instance of `self`.
    ///
    /// - Parameter canDisplayInAppFeedbackCard: If applicable, present the in-app feedback card.
    ///     The in-app feedback card may still not be presented depending on the constraints.
    ///     But setting this to `false`, will ensure that it will never be presented.
    ///
    init(canDisplayInAppFeedbackCard: Bool,
         storesManager: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics) {
        self.canDisplayInAppFeedbackCard = canDisplayInAppFeedbackCard
        self.storesManager = storesManager
        self.analytics = analytics
    }

    /// Must be called by the `ViewController` during the `viewDidAppear()` event. This will
    /// update the visibility of the in-app feedback card.
    ///
    /// The visibility is updated on `viewDidAppear()` to consider scenarios when the app is
    /// never terminated.
    ///
    func onViewDidAppear() {
        refreshIsInAppFeedbackCardVisibleValue()
    }

    /// Updates the card visibility state stored in `isInAppFeedbackCardVisible` by updating the app last feedback date.
    ///
    func onInAppFeedbackCardAction() {
        let action = AppSettingsAction.updateFeedbackStatus(type: .general, status: .given(Date())) { [weak self] result in
            guard let self = self else {
                return
            }

            if let error = result.failure {
                ServiceLocator.crashLogging.logError(error)
            }

            self.refreshIsInAppFeedbackCardVisibleValue()
        }
        storesManager.dispatch(action)
    }

    /// Tracks when the Analytics "See More" button is tapped
    ///
    func trackSeeMoreButtonTapped() {
        analytics.track(event: .AnalyticsHub.seeMoreAnalyticsTapped())
    }

    // MARK: Private helpers

    /// Calculates and updates the value of `isInAppFeedbackCardVisible`.
    private func refreshIsInAppFeedbackCardVisibleValue() {
        // Abort right away if we don't need to calculate the real value.
        guard canDisplayInAppFeedbackCard else {
            return sendIsInAppFeedbackCardVisibleValueAndTrackIfNeeded(false)
        }

        let action = AppSettingsAction.loadFeedbackVisibility(type: .general) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .success(let shouldBeVisible):
                self.sendIsInAppFeedbackCardVisibleValueAndTrackIfNeeded(shouldBeVisible)
            case .failure(let error):
                ServiceLocator.crashLogging.logError(error)
                // We'll just send a `false` value. I think this is the safer bet.
                self.sendIsInAppFeedbackCardVisibleValueAndTrackIfNeeded(false)
            }
        }
        storesManager.dispatch(action)
    }

    /// Updates the value of `isInAppFeedbackCardVisible` and tracks a "shown" event
    /// if the value changed from `false` to `true`.
    private func sendIsInAppFeedbackCardVisibleValueAndTrackIfNeeded(_ newValue: Bool) {
        let trackEvent = isInAppFeedbackCardVisible == false && newValue == true

        isInAppFeedbackCardVisible = newValue
        if trackEvent {
            analytics.track(event: .appFeedbackPrompt(action: .shown))
        }
    }
}
