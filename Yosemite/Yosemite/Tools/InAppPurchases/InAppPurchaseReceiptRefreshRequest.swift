import StoreKit

class InAppPurchaseReceiptRefreshRequest: NSObject, SKRequestDelegate {
    let refreshReceiptRequest: SKReceiptRefreshRequest
    let completion: (Result<Void, Error>) -> Void

    init(completion: @escaping (Result<Void, Error>) -> Void) {
        refreshReceiptRequest = SKReceiptRefreshRequest()
        self.completion = completion
        super.init()
        refreshReceiptRequest.delegate = self
    }

    func requestDidFinish(_ request: SKRequest) {
        complete(.success(()))
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        complete(.failure(error))
    }

    func start() {
        refreshReceiptRequest.start()
    }

    func complete(_ result: Result<Void, Error>) {
        DispatchQueue.main.async { [completion] in
            completion(result)
        }
    }

    static func request() async throws {
        var request: InAppPurchaseReceiptRefreshRequest?
        try await withCheckedThrowingContinuation { continuation in
            request = InAppPurchaseReceiptRefreshRequest { result in
                continuation.resume(with: result)
            }
            request?.start()
        }
    }
}
