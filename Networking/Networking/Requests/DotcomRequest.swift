import Foundation
import Alamofire


/// Represents a WordPress.com Request
///
struct DotcomRequest: Request {

    /// WordPress.com API Version
    ///
    let wordpressApiVersion: WordPressAPIVersion

    /// HTTP Request Method
    ///
    let method: HTTPMethod

    /// RPC
    ///
    let path: String

    /// Parameters
    ///
    let parameters: [String: Any]?

    /// HTTP Headers
    let headers: [String: String]


    /// Designated Initializer.
    ///
    /// - Parameters:
    ///     - wordpressApiVersion: Endpoint Version.
    ///     - method: HTTP Method we should use.
    ///     - path: RPC that should be executed.
    ///     - parameters: Collection of String parameters to be passed over to our target RPC.
    ///
    init(wordpressApiVersion: WordPressAPIVersion, method: HTTPMethod, path: String, parameters: [String: Any]? = nil, headers: [String: String]? = nil) {
        self.wordpressApiVersion = wordpressApiVersion
        self.method = method
        self.path = path
        self.parameters = parameters ?? [:]
        self.headers = headers ?? [:]
    }

    /// Returns a URLRequest instance representing the current WordPress.com Request.
    ///
    func asURLRequest() throws -> URLRequest {
        let dotcomURL = URL(string: Settings.wordpressApiBaseURL + wordpressApiVersion.path + path)!
        let dotcomRequest = try URLRequest(url: dotcomURL, method: method, headers: headers)

        return try URLEncoding.default.encode(dotcomRequest, with: parameters)
    }

    func responseDataValidator() -> ResponseDataValidator {
        switch wordpressApiVersion {
        case .mark1_1, .mark1_2, .mark1_5:
            return DotcomValidator()
        case .wpcomMark2, .wpMark2:
            return WordPressApiValidator()
        }
    }
}
