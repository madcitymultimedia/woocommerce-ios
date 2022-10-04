import Combine
import Foundation
import protocol Alamofire.URLRequestConvertible

/// Represents a collection of Remote Endpoints
///
public class Remote {

    /// Networking Wrapper: Dependency Injection Mechanism, useful for Unit Testing purposes.
    ///
    let network: Network


    /// Designated Initializer.
    ///
    /// - Parameters:
    ///     - credentials: Credentials to be used in order to authenticate every request.
    ///     - network: Network Wrapper, in charge of actually enqueueing a given network request.
    ///
    public init(network: Network) {
        self.network = network
    }


    /// Enqueues the specified Network Request with a generic expected result type.
    ///
    /// - Parameter request: Request that should be performed.
    /// - Returns: The result from the JSON parsed response for the expected type.
    func enqueue<T>(_ request: URLRequestConvertible) async -> Result<T, Error> {
        await withCheckedContinuation { continuation in
            network.responseData(for: request) { [weak self] result in
                guard let self = self else {
                    return
                }

                switch result {
                case .success(let data):
                    if let dotcomError = DotcomValidator.error(from: data) {
                        self.dotcomErrorWasReceived(error: dotcomError, for: request)
                        continuation.resume(returning: .failure(dotcomError))
                        return
                    }

                    do {
                        guard let document = try JSONSerialization.jsonObject(with: data, options: []) as? T else {
                            return continuation.resume(returning: .failure(RemoteError.unexpectedResponseData))
                        }
                        continuation.resume(returning: .success(document))
                    } catch {
                        continuation.resume(returning: .failure(error))
                    }
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }


    /// Enqueues the specified Network Request.
    ///
    /// - Important:
    ///     - Parsing will be performed by the Mapper.
    ///
    /// - Parameters:
    ///     - request: Request that should be performed.
    ///     - mapper: Mapper entity that will be used to attempt to parse the Backend's Response.
    ///     - completion: Closure to be executed upon completion.
    ///
    func enqueue<M: Mapper>(_ request: URLRequestConvertible, mapper: M, completion: @escaping (M.Output?, Error?) -> Void) {
        network.responseData(for: request) { [weak self] (data, networkError) in
            guard let self = self else {
                return
            }

            guard let data = data else {
                completion(nil, networkError)
                return
            }

            if let dotcomError = DotcomValidator.error(from: data) {
                self.dotcomErrorWasReceived(error: dotcomError, for: request)
                completion(nil, dotcomError)
                return
            }

            do {
                let parsed = try mapper.map(response: data)
                completion(parsed, nil)
            } catch {
                DDLogError("<> Mapping Error: \(error)")
                completion(nil, error)
            }
        }
    }

    /// Enqueues the specified Network Request.
    ///
    /// - Important:
    ///     - Parsing will be performed by the Mapper.
    ///
    /// - Parameters:
    ///     - request: Request that should be performed.
    ///     - mapper: Mapper entity that will be used to attempt to parse the Backend's Response.
    ///     - completion: Closure to be executed upon completion.
    ///
    func enqueue<M: Mapper>(_ request: URLRequestConvertible, mapper: M,
                            completion: @escaping (Result<M.Output, Error>) -> Void) {
        network.responseData(for: request) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .success(let data):
                if let dotcomError = DotcomValidator.error(from: data) {
                    self.dotcomErrorWasReceived(error: dotcomError, for: request)
                    completion(.failure(dotcomError))
                    return
                }

                do {
                    let parsed = try mapper.map(response: data)
                    completion(.success(parsed))
                } catch {
                    DDLogError("<> Mapping Error: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Returns a publisher that enqueues the specified Network Request on subscription and emits the result upon completion.
    ///
    /// - Important:
    ///     - Parsing will be performed by the Mapper.
    ///
    /// - Parameters:
    ///     - request: Request that should be performed.
    ///     - mapper: Mapper entity that will be used to attempt to parse the Backend's Response.
    ///
    /// - Returns: A publisher that emits result upon completion.
    func enqueue<M: Mapper>(_ request: URLRequestConvertible, mapper: M) -> AnyPublisher<Result<M.Output, Error>, Never> {
        network.responseDataPublisher(for: request)
            .map { (result: Result<Data, Error>) -> Result<M.Output, Error> in
                switch result {
                case .success(let data):
                    if let dotcomError = DotcomValidator.error(from: data) {
                        return .failure(dotcomError)
                    }

                    do {
                        let parsed = try mapper.map(response: data)
                        return .success(parsed)
                    } catch {
                        DDLogError("<> Mapping Error: \(error)")
                        return .failure(error)
                    }
                case .failure(let error):
                    return .failure(error)
                }
            }
            .handleEvents(receiveOutput: { [weak self] result in
                if let dotcomError = result.failure as? DotcomError {
                    self?.dotcomErrorWasReceived(error: dotcomError, for: request)
                }
            })
            .eraseToAnyPublisher()
    }

    /// Enqueues the specified Network Request for upload with multipart form data encoding.
    ///
    /// - Important:
    ///     - Parsing will be performed by the Mapper.
    ///
    /// - Parameters:
    ///     - request: Request that should be performed.
    ///     - mapper: Mapper entitity that will be used to attempt to parse the Backend's Response.
    ///     - multipartFormData: Used for appending data for multipart form data uploads.
    ///     - completion: Closure to be executed upon completion.
    ///
    func enqueueMultipartFormDataUpload<M: Mapper>(_ request: URLRequestConvertible,
                                                   mapper: M,
                                                   multipartFormData: @escaping (MultipartFormData) -> Void,
                                                   completion: @escaping (Result<M.Output, Error>) -> Void) {
        network.uploadMultipartFormData(multipartFormData: multipartFormData,
                                        to: request) { [weak self] (data, networkError) in
                                            guard let self = self else {
                                                return
                                            }

                                            guard let data = data else {
                                                completion(.failure(networkError ?? NetworkError.notFound))
                                                return
                                            }

                                            if let dotcomError = DotcomValidator.error(from: data) {
                                                self.dotcomErrorWasReceived(error: dotcomError, for: request)
                                                completion(.failure(dotcomError))
                                                return
                                            }

                                            do {
                                                let parsed = try mapper.map(response: data)
                                                completion(.success(parsed))
                                            } catch {
                                                DDLogError("<> Mapping Error: \(error)")
                                                completion(.failure(error))
                                            }
        }
    }
}


// MARK: - Private Methods
//
private extension Remote {

    /// Handles *all* of the DotcomError(s) that are successfully parsed.
    ///
    func dotcomErrorWasReceived(error: Error, for request: URLRequestConvertible) {
        guard let dotcomError = error as? DotcomError else {
            return
        }

        switch dotcomError {
        case .requestFailed where request is JetpackRequest:
            publishJetpackTimeoutNotification(error: dotcomError)
        case .invalidToken:
            publishInvalidTokenNotification(error: dotcomError)
        default:
            break
        }
    }


    /// Publishes a `Jetpack Timeout` Notification.
    ///
    private func publishJetpackTimeoutNotification(error: DotcomError) {
        NotificationCenter.default.post(name: .RemoteDidReceiveJetpackTimeoutError, object: error, userInfo: nil)
    }

    /// Publishes an `Invalid Token` Notification.
    ///
    private func publishInvalidTokenNotification(error: DotcomError) {
        NotificationCenter.default.post(name: .RemoteDidReceiveInvalidTokenError, object: error, userInfo: nil)
    }
}

// MARK: - Constants!
//
public extension Remote {

    enum Default {
        public static let firstPageNumber: Int = 1
    }
}


// MARK: - Remote Notifications
//
public extension NSNotification.Name {

    /// Posted whenever an Invalid Token Error is received.
    ///
    static let RemoteDidReceiveInvalidTokenError = NSNotification.Name(rawValue: "RemoteDidReceiveInvalidTokenError")

    /// Posted whenever a Jetpack Timeout is received.
    ///
    static let RemoteDidReceiveJetpackTimeoutError = NSNotification.Name(rawValue: "RemoteDidReceiveJetpackTimeoutError")
}

enum RemoteError: Error {
    /// The response data does not match the expected type.
    case unexpectedResponseData
}
