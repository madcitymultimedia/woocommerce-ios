import Foundation
import Yosemite
import WooFoundation

/// Calculates the total value(cost + tax) to be refunded from a shipping line.
///
struct RefundShippingCalculationUseCase {

    /// Shipping line to be refunded
    ///
    let shippingLine: ShippingLine

    /// Formatter to convert string values to decimal values
    ///
    let currencyFormatter: CurrencyFormatter

    /// Calculates the total value(cost + tax) to be refunded.
    ///
    func calculateRefundValue() -> Decimal {
        guard let cost = currencyFormatter.convertToDecimal(shippingLine.total) as Decimal?,
            let tax = currencyFormatter.convertToDecimal(shippingLine.totalTax) as Decimal? else {
                return .zero
        }
        return cost + tax
    }
}
