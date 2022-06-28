import ScreenObject
import XCTest

public final class CardPresentPaymentsModalScreen: ScreenObject {

    private let dismissButtonGetter: (XCUIApplication) -> XCUIElement = {
        $0.buttons["card-present-payments-modal-secondary-button"]
    }

    /// Button to dismiss a the modal
    ///
    private var dismissButton: XCUIElement { dismissButtonGetter(app) }

    init(app: XCUIApplication = XCUIApplication()) throws {
        try super.init(
            expectedElementGetters: [ { $0.staticTexts["card-present-payments-modal-title-label"]} ],
            app: app
        )
    }

    @discardableResult
    public func goBackToOrderScreen() throws -> SingleOrderScreen {
        dismissButton.tap()
        return try SingleOrderScreen()
    }
}
