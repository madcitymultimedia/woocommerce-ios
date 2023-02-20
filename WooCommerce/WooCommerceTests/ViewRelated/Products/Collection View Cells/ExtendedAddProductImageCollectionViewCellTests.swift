import XCTest
@testable import WooCommerce

final class ExtendedAddProductImageCollectionViewCellTests: XCTestCase {

    private var cell: ExtendedAddProductImageCollectionViewCell?

    override func setUp() {
        super.setUp()
        let nib = Bundle.main.loadNibNamed("ExtendedAddProductImageCollectionViewCell", owner: self, options: nil)
        cell = nib?.first as? ExtendedAddProductImageCollectionViewCell
    }

    override func tearDown() {
        cell = nil
        super.tearDown()
    }

    func testImageViewIsNotEmpty() {
        XCTAssertNotNil(cell?.imageView.image)
    }

    func testImageViewConfiguration() {
        XCTAssertEqual(cell?.imageView.contentMode, .center)
        XCTAssertEqual(cell?.imageView.clipsToBounds, true)
    }

    func testTextLabelStyleIsSetToBody() {
        let mockLabel = UILabel()
        mockLabel.applyEmptyStateTitleStyle()

        XCTAssertEqual(cell?.title?.font, mockLabel.font)
        XCTAssertEqual(cell?.title?.textColor, mockLabel.textColor)
    }

    func testVariationAndProductProductImageLabelsDiffer() {
        cell?.configurePlaceholderLabelForProductImages(isVariation: true)
        let variationLabel = cell?.title?.text

        cell?.configurePlaceholderLabelForProductImages(isVariation: false)
        let productLabel = cell?.title?.text

        XCTAssertNotEqual(variationLabel, productLabel)
    }
}
