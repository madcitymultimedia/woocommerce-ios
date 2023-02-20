import Foundation


/// String: Constant Helpers
///
extension String {

    /// Returns a string containing the Hair Space.
    ///
    static var hairSpace: String {
        return "\u{200A}"
    }

    /// Returns a string containing a Space.
    ///
    static var space: String {
        return " "
    }
}


/// String: URL manipulation
///
extension String {
    var hasValidSchemeForBrowser: Bool {
        hasPrefix("http://") || hasPrefix("https://")
    }

    func addHTTPSSchemeIfNecessary() -> String {
        if hasValidSchemeForBrowser {
            return self
        }

        return "https://\(self)"
    }


    /// Removes the scheme of a url
    /// - Returns: a url without scheme, or the initial string
    func trimHTTPScheme() -> String {
        guard let urlComponents = URLComponents(string: self),
              let host = urlComponents.host else {
            return self
        }

        return host + urlComponents.path
    }
}
