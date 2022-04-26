#if !targetEnvironment(macCatalyst)
import StripeTerminal

extension Hardware.PaymentIntentParameters {
    /// Initializes a StripeTerminal.PaymentIntentParameters from a
    /// Hardware.PaymentIntentParameters
    func toStripe() -> StripeTerminal.PaymentIntentParameters? {
        // Shortcircuit if we do not have a valid currency code
        guard !currency.isEmpty else {
            return nil
        }

        // Shortcircuit if we do not have a valid payment method
        guard !paymentMethodTypes.isEmpty else {
            return nil
        }

        /// The amount of the payment needs to be provided in the currency’s smallest unit.
        /// https://stripe.dev/stripe-terminal-ios/docs/Classes/SCPPaymentIntentParameters.html#/c:objc(cs)SCPPaymentIntentParameters(py)amount
        let amountInSmallestUnit = amount * 100

        let amountForStripe = NSDecimalNumber(decimal: amountInSmallestUnit).uintValue

        let returnValue = StripeTerminal.PaymentIntentParameters(amount: amountForStripe, currency: currency, paymentMethodTypes: paymentMethodTypes)
        returnValue.stripeDescription = receiptDescription

        let applicationFeeForStripe = NSDecimalNumber(decimal: amountInSmallestUnit * 0.1)
        returnValue.applicationFeeAmount = applicationFeeForStripe

        /// Stripe allows the credit card statement descriptor to be nil, but not an empty string
        /// https://stripe.dev/stripe-terminal-ios/docs/Classes/SCPPaymentIntentParameters.html#/c:objc(cs)SCPPaymentIntentParameters(py)statementDescriptor
        returnValue.statementDescriptor = nil
        let descriptor = statementDescription ?? ""
        if !descriptor.isEmpty {
            returnValue.statementDescriptor = descriptor
        }

        returnValue.receiptEmail = receiptEmail
        returnValue.metadata = metadata

        return returnValue
    }
}
#endif
