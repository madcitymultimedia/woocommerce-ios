import XCTest
@testable import Networking

final class SiteRemoteTests: XCTestCase {
    /// Mock network wrapper.
    private var network: MockNetwork!

    private var remote: SiteRemote!

    override func setUp() {
        super.setUp()
        network = MockNetwork()
        remote = SiteRemote(network: network, dotcomClientID: "", dotcomClientSecret: "")
    }

    override func tearDown() {
        remote = nil
        network = nil
        super.tearDown()
    }

    func test_createSite_returns_created_site_on_success() async throws {
        // Given
        network.simulateResponse(requestUrlSuffix: "sites/new", filename: "site-creation-success")

        // When
        let result = await remote.createSite(name: "Wapuu swags", domain: "wapuu.store")

        // Then
        XCTAssertTrue(result.isSuccess)
        let response = try XCTUnwrap(result.get())
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.site, .init(siteID: "202211",
                                            name: "Wapuu swags",
                                            url: "https://wapuu.store/",
                                            siteSlug: "wapuu.store"))
    }

    func test_createSite_returns_invalidDomain_error_when_domain_is_empty() async throws {
        // When
        let result = await remote.createSite(name: "Wapuu swags", domain: "")

        // Then
        let error = try XCTUnwrap(result.failure as? SiteCreationError)
        XCTAssertEqual(error, .invalidDomain)
    }

    func test_createSite_returns_DotcomError_failure_on_domain_error() async throws {
        // Given
        network.simulateResponse(requestUrlSuffix: "sites/new", filename: "site-creation-domain-error")

        // When
        let result = await remote.createSite(name: "Wapuu swags", domain: "wapuu.store")

        // Then
        let error = try XCTUnwrap(result.failure as? DotcomError)
        XCTAssertEqual(error,
                       .unknown(code: "blog_name_only_lowercase_letters_and_numbers",
                                message: "Site names can only contain lowercase letters (a-z) and numbers."))
    }

    func test_createSite_returns_failure_on_empty_response() async throws {
        // When
        let result = await remote.createSite(name: "Wapuu swags", domain: "wapuu.store")

        // Then
        let error = try XCTUnwrap(result.failure as? NetworkError)
        XCTAssertEqual(error, .notFound)
    }
}
