import Networking
import XCTest

/// Mock for `SiteRemote`.
///
final class MockSiteRemote {
    /// The results to return in `createSite`.
    private var createSiteResult: Result<SiteCreationResponse, Error>?

    /// Returns the value when `createSite` is called.
    func whenCreatingSite(thenReturn result: Result<SiteCreationResponse, Error>) {
        createSiteResult = result
    }
}

extension MockSiteRemote: SiteRemoteProtocol {
    func createSite(name: String, domain: String) async throws -> SiteCreationResponse {
        guard let result = createSiteResult else {
            XCTFail("Could not find result for creating a site.")
            throw NetworkError.notFound
        }

        return try result.get()
    }
}
