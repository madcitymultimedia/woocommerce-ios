import XCTest
@testable import WooCommerce
import Yosemite
import WooFoundation

/// CurrencySettings Tests
///
final class CurrencySettingsTests: XCTestCase {

    private var moneyFormat: CurrencySettings?
    private var siteSettings: [SiteSetting] = []

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        moneyFormat = nil
        siteSettings = []
        super.tearDown()
    }

    func testInitDefault() {
        moneyFormat = CurrencySettings()

        XCTAssertEqual(.USD, moneyFormat?.currencyCode)
        XCTAssertEqual(.left, moneyFormat?.currencyPosition)
        XCTAssertEqual(".", moneyFormat?.decimalSeparator)
        XCTAssertEqual(2, moneyFormat?.fractionDigits)
        XCTAssertEqual(",", moneyFormat?.groupingSeparator)
    }

    func testInitWithIndividualParameters() {
        moneyFormat = CurrencySettings(currencyCode: .USD,
                                       currencyPosition: .right,
                                       thousandSeparator: "M",
                                       decimalSeparator: "X",
                                       numberOfDecimals: 10)

        XCTAssertEqual(.USD, moneyFormat?.currencyCode)
        XCTAssertEqual(.right, moneyFormat?.currencyPosition)
        XCTAssertEqual("X", moneyFormat?.decimalSeparator)
        XCTAssertEqual(10, moneyFormat?.fractionDigits)
        XCTAssertEqual("M", moneyFormat?.groupingSeparator)
    }

    func testInitWithSiteSettingsEmptyArray() {
        siteSettings = []
        moneyFormat = CurrencySettings(siteSettings: siteSettings)

        XCTAssertEqual(.USD, moneyFormat?.currencyCode)
        XCTAssertEqual(.left, moneyFormat?.currencyPosition)
        XCTAssertEqual(".", moneyFormat?.decimalSeparator)
        XCTAssertEqual(2, moneyFormat?.fractionDigits)
        XCTAssertEqual(",", moneyFormat?.groupingSeparator)
    }

    func testInitWithSiteSettings() {
        let wooCurrencyCode = SiteSetting(siteID: 1,
                                          settingID: "woocommerce_currency",
                                          label: "",
                                          settingDescription: "",
                                          value: "SHP",
                                          settingGroupKey: SiteSettingGroup.general.rawValue)

        let wooCurrencyPosition = SiteSetting(siteID: 1,
                                              settingID: "woocommerce_currency_pos",
                                              label: "",
                                              settingDescription: "",
                                              value: "right",
                                              settingGroupKey: SiteSettingGroup.general.rawValue)

        let thousandsSeparator = SiteSetting(siteID: 1,
                                             settingID: "woocommerce_price_thousand_sep",
                                             label: "",
                                             settingDescription: "",
                                             value: "X",
                                             settingGroupKey: SiteSettingGroup.general.rawValue)

        let decimalSeparator = SiteSetting(siteID: 1,
                                           settingID: "woocommerce_price_decimal_sep",
                                           label: "",
                                           settingDescription: "",
                                           value: "Y",
                                           settingGroupKey: SiteSettingGroup.general.rawValue)

        let numberOfDecimals = SiteSetting(siteID: 1,
                                           settingID: "woocommerce_price_num_decimals",
                                           label: "",
                                           settingDescription: "",
                                           value: "3",
                                           settingGroupKey: SiteSettingGroup.general.rawValue)

        siteSettings = [wooCurrencyCode,
                        wooCurrencyPosition,
                        thousandsSeparator,
                        decimalSeparator,
                        numberOfDecimals]

        moneyFormat = CurrencySettings(siteSettings: siteSettings)

        XCTAssertEqual(.SHP, moneyFormat?.currencyCode)
        XCTAssertEqual(.right, moneyFormat?.currencyPosition)
        XCTAssertEqual("Y", moneyFormat?.decimalSeparator)
        XCTAssertEqual(3, moneyFormat?.fractionDigits)
        XCTAssertEqual("X", moneyFormat?.groupingSeparator)
    }

    func testInitWithIncompleteSiteSettings() {
        let wooCurrencyCode = SiteSetting(siteID: 1,
                                          settingID: "woocommerce_currency",
                                          label: "",
                                          settingDescription: "",
                                          value: "SHP",
                                          settingGroupKey: SiteSettingGroup.general.rawValue)

        let wooCurrencyPosition = SiteSetting(siteID: 1,
                                              settingID: "woocommerce_currency_pos",
                                              label: "",
                                              settingDescription: "",
                                              value: "right",
                                              settingGroupKey: SiteSettingGroup.general.rawValue)

        let thousandsSeparator = SiteSetting(siteID: 1,
                                             settingID: "woocommerce_price_thousand_sep",
                                             label: "",
                                             settingDescription: "",
                                             value: "X",
                                             settingGroupKey: SiteSettingGroup.general.rawValue)

        let decimalSeparator = SiteSetting(siteID: 1,
                                           settingID: "woocommerce_price_decimal_sep",
                                           label: "",
                                           settingDescription: "",
                                           value: "Y",
                                           settingGroupKey: SiteSettingGroup.general.rawValue)

        // Note that the above is missing a declaration for the number of decimals; this lets us test that it is using the default number, 2.

        siteSettings = [wooCurrencyCode,
                        wooCurrencyPosition,
                        thousandsSeparator,
                        decimalSeparator]

        moneyFormat = CurrencySettings(siteSettings: siteSettings)

        XCTAssertEqual(.SHP, moneyFormat?.currencyCode)
        XCTAssertEqual(.right, moneyFormat?.currencyPosition)
        XCTAssertEqual("Y", moneyFormat?.decimalSeparator)
        XCTAssertEqual(2, moneyFormat?.fractionDigits)
        XCTAssertEqual("X", moneyFormat?.groupingSeparator)
    }

    /// Test currency symbol lookup returns correctly encoded symbol.
    ///
    func testCurrencySymbol() {
        moneyFormat = CurrencySettings()
        let symbol = moneyFormat?.symbol(from: CurrencyCode.AED)
        XCTAssertEqual("د.إ", symbol)
    }
}
