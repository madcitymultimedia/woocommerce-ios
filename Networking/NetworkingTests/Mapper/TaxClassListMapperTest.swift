import XCTest
@testable import Networking


/// TaxClassListMapper Unit Tests
///
final class TaxClassListMapperTest: XCTestCase {

    /// Testing SiteID
    ///
    private let sampleSiteID: Int64 = 123

    /// Verifies that all of the Tax Class Fields are parsed correctly.
    ///
    func test_TaxClass_fields_are_properly_parsed() {
        let taxClasses = mapLoadAllTaxClassResponse()
        XCTAssertEqual(taxClasses.count, 3)


        let firstTaxClass = taxClasses[0]
        XCTAssertEqual(firstTaxClass.siteID, sampleSiteID)
        XCTAssertEqual(firstTaxClass.slug, "standard")
        XCTAssertEqual(firstTaxClass.name, "Standard Rate")
    }

    /// Verifies that all of the Tax Class Fields are parsed correctly.
    ///
    func test_TaxClass_fields_are_properly_parsed_when_response_has_no_data_envelope() {
        let taxClasses = mapLoadAllTaxClassResponseWithoutDataEnvelope()
        XCTAssertEqual(taxClasses.count, 3)


        let firstTaxClass = taxClasses[0]
        XCTAssertEqual(firstTaxClass.siteID, sampleSiteID)
        XCTAssertEqual(firstTaxClass.slug, "standard")
        XCTAssertEqual(firstTaxClass.name, "Standard Rate")
    }
}


/// Private Methods.
///
private extension TaxClassListMapperTest {

    /// Returns the TaxClassListMapper output upon receiving `filename` (Data Encoded)
    ///
    func mapTaxClasses(from filename: String) -> [TaxClass] {
        guard let response = Loader.contentsOf(filename) else {
            return []
        }

        return try! TaxClassListMapper(siteID: sampleSiteID).map(response: response)
    }

    /// Returns the TaxClassListMapper output upon receiving `taxes-classes`
    ///
    func mapLoadAllTaxClassResponse() -> [TaxClass] {
        return mapTaxClasses(from: "taxes-classes")
    }

    /// Returns the TaxClassListMapper output upon receiving `taxes-classes-without-data`
    ///
    func mapLoadAllTaxClassResponseWithoutDataEnvelope() -> [TaxClass] {
        return mapTaxClasses(from: "taxes-classes-without-data")
    }
}
