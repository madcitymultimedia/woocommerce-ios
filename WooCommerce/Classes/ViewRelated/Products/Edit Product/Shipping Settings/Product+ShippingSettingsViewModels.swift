import Yosemite

extension Product {

    private static let placeholder = "0"

    static func createShippingWeightViewModel(weight: String?,
                                              using shippingSettingsService: ShippingSettingsService,
                                              onInputChange: @escaping (_ input: String?) -> Void) -> UnitInputViewModel {
        let title = NSLocalizedString("Weight", comment: "Title of the cell in Product Shipping Settings > Weight")
        let unit = shippingSettingsService.weightUnit ?? ""
        let value = weight == nil || weight?.isEmpty == true ? "": weight
        let accessibilityHint = NSLocalizedString(
            "The shipping weight for this product. Editable.",
            comment: "VoiceOver accessibility hint, informing the user that the cell shows the shipping weight information for this product.")
        return UnitInputViewModel(title: title,
                                  unit: unit,
                                  value: value,
                                  placeholder: placeholder,
                                  accessibilityHint: accessibilityHint,
                                  unitPosition: .afterInput,
                                  keyboardType: .decimalPad,
                                  inputFormatter: ShippingInputFormatter(),
                                  style: .primary,
                                  onInputChange: onInputChange)
    }

    static func createShippingLengthViewModel(length: String,
                                              using shippingSettingsService: ShippingSettingsService,
                                              onInputChange: @escaping (_ input: String?) -> Void) -> UnitInputViewModel {
        let title = NSLocalizedString("Length", comment: "Title of the cell in Product Shipping Settings > Length")
        let unit = shippingSettingsService.dimensionUnit ?? ""
        let accessibilityHint = NSLocalizedString(
            "The shipping length for this product. Editable.",
            comment: "VoiceOver accessibility hint, informing the user that the cell shows the shipping length information for this product.")
        return UnitInputViewModel(title: title,
                                  unit: unit,
                                  value: length,
                                  placeholder: placeholder,
                                  accessibilityHint: accessibilityHint,
                                  unitPosition: .afterInput,
                                  keyboardType: .decimalPad,
                                  inputFormatter: ShippingInputFormatter(),
                                  style: .primary,
                                  onInputChange: onInputChange)
    }

    static func createShippingWidthViewModel(width: String,
                                             using shippingSettingsService: ShippingSettingsService,
                                             onInputChange: @escaping (_ input: String?) -> Void) -> UnitInputViewModel {
        let title = NSLocalizedString("Width", comment: "Title of the cell in Product Shipping Settings > Width")
        let unit = shippingSettingsService.dimensionUnit ?? ""
        let accessibilityHint = NSLocalizedString(
            "The shipping width for this product. Editable.",
            comment: "VoiceOver accessibility hint, informing the user that the cell shows the shipping width information for this product.")
        return UnitInputViewModel(title: title,
                                  unit: unit,
                                  value: width,
                                  placeholder: placeholder,
                                  accessibilityHint: accessibilityHint,
                                  unitPosition: .afterInput,
                                  keyboardType: .decimalPad,
                                  inputFormatter: ShippingInputFormatter(),
                                  style: .primary,
                                  onInputChange: onInputChange)
    }

    static func createShippingHeightViewModel(height: String,
                                              using shippingSettingsService: ShippingSettingsService,
                                              onInputChange: @escaping (_ input: String?) -> Void) -> UnitInputViewModel {
        let title = NSLocalizedString("Height", comment: "Title of the cell in Product Shipping Settings > Height")
        let unit = shippingSettingsService.dimensionUnit ?? ""
        let accessibilityHint = NSLocalizedString(
            "The shipping height for this product. Editable.",
            comment: "VoiceOver accessibility hint, informing the user that the cell shows the shipping height information for this product.")
        return UnitInputViewModel(title: title,
                                  unit: unit,
                                  value: height,
                                  placeholder: placeholder,
                                  accessibilityHint: accessibilityHint,
                                  unitPosition: .afterInput,
                                  keyboardType: .decimalPad,
                                  inputFormatter: ShippingInputFormatter(),
                                  style: .primary,
                                  onInputChange: onInputChange)
    }
}
