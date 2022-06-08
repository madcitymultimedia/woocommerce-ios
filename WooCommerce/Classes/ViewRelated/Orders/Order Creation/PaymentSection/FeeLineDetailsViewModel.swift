import SwiftUI
import Yosemite
import WooFoundation

class FeeLineDetailsViewModel: ObservableObject {

    /// Closure to be invoked when the fee line is updated.
    ///
    var didSelectSave: ((OrderFeeLine?) -> Void)

    /// Helper to format price field input.
    ///
    private let priceFieldFormatter: PriceFieldFormatter

    /// Stores the fixed amount entered by the merchant.
    ///
    @Published var amount: String = "" {
        didSet {
            guard amount != oldValue else { return }
            amount = priceFieldFormatter.formatAmount(amount)
        }
    }

    /// Stores the percentage entered by the merchant.
    ///
    @Published var percentage: String = "" {
        didSet {
            guard percentage != oldValue else { return }
            percentage = sanitizePercentageAmount(percentage)
        }
    }

    /// Decimal value of currently entered fee. For percentage type it is calculated final amount.
    ///
    private var finalAmountDecimal: Decimal {
        let inputString = feeType == .fixed ? amount : percentage
        guard let decimalInput = currencyFormatter.convertToDecimal(inputString) else {
            return .zero
        }

        switch feeType {
        case .fixed:
            return decimalInput as Decimal
        case .percentage:
            return baseAmountForPercentage * (decimalInput as Decimal) * 0.01
        }
    }

    /// Formatted string value of currently entered fee. For percentage type it is calculated final amount.
    ///
    var finalAmountString: String? {
        currencyFormatter.formatAmount(finalAmountDecimal)
    }

    /// The base amount (items + shipping) to apply percentage fee on.
    ///
    private let baseAmountForPercentage: Decimal

    /// The initial fee amount.
    ///
    private let initialAmount: Decimal

    /// Returns true when existing fee line is edited.
    ///
    let isExistingFeeLine: Bool

    /// Returns true when base amount for percentage > 0.
    ///
    var isPercentageOptionAvailable: Bool {
        !isExistingFeeLine && baseAmountForPercentage > 0
    }

    /// Returns true when there are no valid pending changes.
    ///
    var shouldDisableDoneButton: Bool {
        guard finalAmountDecimal != .zero else {
            return true
        }

        return finalAmountDecimal == initialAmount
    }

    /// Localized percent symbol.
    ///
    let percentSymbol: String

    /// Current store currency symbol.
    ///
    let currencySymbol: String

    /// Position for currency symbol, relative to amount text field.
    ///
    let currencyPosition: CurrencySettings.CurrencyPosition

    /// Currency formatter setup with store settings.
    ///
    private let currencyFormatter: CurrencyFormatter

    private let minusSign: String = NumberFormatter().minusSign

    /// Placeholder for amount text field.
    ///
    let amountPlaceholder: String

    enum FeeType {
        case fixed
        case percentage
    }

    @Published var feeType: FeeType = .fixed

    init(isExistingFeeLine: Bool,
         baseAmountForPercentage: Decimal,
         feesTotal: String,
         locale: Locale = Locale.autoupdatingCurrent,
         storeCurrencySettings: CurrencySettings = ServiceLocator.currencySettings,
         didSelectSave: @escaping ((OrderFeeLine?) -> Void)) {
        self.priceFieldFormatter = .init(locale: locale, storeCurrencySettings: storeCurrencySettings, allowNegativeNumber: true)
        self.percentSymbol = NumberFormatter().percentSymbol
        self.currencySymbol = storeCurrencySettings.symbol(from: storeCurrencySettings.currencyCode)
        self.currencyPosition = storeCurrencySettings.currencyPosition
        self.currencyFormatter = CurrencyFormatter(currencySettings: storeCurrencySettings)
        self.amountPlaceholder = priceFieldFormatter.formatAmount("0")

        self.isExistingFeeLine = isExistingFeeLine
        self.baseAmountForPercentage = baseAmountForPercentage

        if let initialAmount = currencyFormatter.convertToDecimal(feesTotal) {
            self.initialAmount = initialAmount as Decimal
        } else {
            self.initialAmount = .zero
        }

        if initialAmount != 0, let formattedInputAmount = currencyFormatter.formatAmount(initialAmount) {
            self.amount = priceFieldFormatter.formatAmount(formattedInputAmount)
            self.percentage = priceFieldFormatter.formatAmount("\(initialAmount / baseAmountForPercentage * 100)")
        }

        self.didSelectSave = didSelectSave
    }

    func saveData() {
        guard let finalAmountString = finalAmountString else {
            return
        }

        let feeLine = OrderFactory.newOrderFee(total: priceFieldFormatter.formatAmount(finalAmountString))
        didSelectSave(feeLine)
    }
}

private extension FeeLineDetailsViewModel {

    /// Formats a received value by sanitizing the input and trimming content to two decimal places.
    ///
    func sanitizePercentageAmount(_ amount: String) -> String {
        let deviceDecimalSeparator = Locale.autoupdatingCurrent.decimalSeparator ?? "."
        let numberOfDecimals = 2

        let negativePrefix = amount.hasPrefix(minusSign) ? minusSign : ""

        let sanitized = amount
            .filter { $0.isNumber || "\($0)" == deviceDecimalSeparator }

        // Trim to two decimals & remove any extra "."
        let components = sanitized.components(separatedBy: deviceDecimalSeparator)
        switch components.count {
        case 1 where sanitized.contains(deviceDecimalSeparator):
            return negativePrefix + components[0] + deviceDecimalSeparator
        case 1:
            return negativePrefix + components[0]
        case 2...Int.max:
            let number = components[0]
            let decimals = components[1]
            let trimmedDecimals = decimals.prefix(numberOfDecimals)
            return negativePrefix + number + deviceDecimalSeparator + trimmedDecimals
        default:
            fatalError("Should not happen, components can't be 0 or negative")
        }
    }
}
