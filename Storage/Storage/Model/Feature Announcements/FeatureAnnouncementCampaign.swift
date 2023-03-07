import Foundation

public enum FeatureAnnouncementCampaign: String, Codable, Equatable {
    case upsellCardReaders = "upsell_card_readers"
    case linkedProductsPromo = "linked_products_promo"
    case productsOnboarding = "products_onboarding_first_product"
    case inPersonPaymentsCashOnDelivery = "ipp_not_user"
    case inPersonPaymentsFirstTransaction = "ipp_new_user"
    case inPersonPaymentsPowerUsers = "ipp_power_user"

    /// Added for use in `test_setFeatureAnnouncementDismissed_with_another_campaign_previously_dismissed_keeps_values_for_both`
    /// This can be removed when we have a second campaign, which can be used in the above test instead.
    case test
}
