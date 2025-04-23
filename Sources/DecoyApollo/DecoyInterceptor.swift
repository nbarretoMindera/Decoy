import Apollo
import ApolloAPI
import Decoy
import Foundation

/// Errors that can occur during the interception and handling of GraphQL requests by `DecoyInterceptor`.
public enum DecoyInterceptorError: Error {
  /// Indicates that no stub was found in the Decoy queue while operating in `forceOffline` mode.
  case stubNotFoundInForceOfflineMode
  /// Indicates that a recorded stub response was found but contains no data.
  case recordedStubContainsNoData
  /// Indicates failure to parse stub or live response data into JSON.
  case couldNotParseToJSON
  /// Indicates an invalid URLRequest was encountered during processing.
  case invalidURLRequest
}

/// An Apollo interceptor that integrates the Decoy mocking framework into the request chain.
///
/// `DecoyInterceptor` is designed to be used within Apollo's interceptor chain to intercept GraphQL
/// requests. It attempts to fulfill requests from Decoy's stub queue to enable offline or mocked responses.
/// If a stub is available for the request, it returns the stubbed response immediately without performing a network call.
/// If no stub is available and Decoy is in `forceOffline` mode, it fails the request.
/// Otherwise, it allows the request to proceed to the network and, if Decoy is in `record` mode,
/// records the live response for future stubbing.
///
/// This interceptor enables seamless switching between live network requests and stubbed responses,
/// facilitating testing, offline support, and response recording for GraphQL operations.
public class DecoyInterceptor: ApolloInterceptor {

  /// A unique identifier for this interceptor.
  public var id: String {
    "DecoyInterceptor"
  }

  /// The Decoy instance used to manage stubbing and recording.
  public let decoy: Decoy

  /// Creates a new `DecoyInterceptor` with the specified Decoy instance.
  ///
  /// - Parameter decoy: The Decoy instance that manages stub queues and recording.
  public init(decoy: Decoy = .shared) {
    self.decoy = decoy
  }

  /// Intercepts a GraphQL request to provide a stubbed response from Decoy's queue or proceed with a live network request.
  ///
  /// The interception logic follows these steps:
  /// 1. Attempts to convert the Apollo `HTTPRequest` to a `URLRequest` and generate a `GraphQLSignature` from it.
  ///    If this fails, the request is completed with an error.
  /// 2. Queries Decoy's stub queue for a stub response matching the generated signature.
  ///    - If a stub is found:
  ///      - Validates that the stub contains data.
  ///      - Parses the stub data into a JSON object.
  ///      - Constructs a `GraphQLResponse` from the operation and parsed JSON.
  ///      - Parses the response into a `GraphQLResult` and completes with this stubbed result.
  ///    - If no stub is found and Decoy is in `forceOffline` mode, completes with a `stubNotFoundInForceOfflineMode` error.
  /// 3. If no stub is found and not in `forceOffline` mode, allows the request to proceed to the network.
  ///    - Upon receiving a live response:
  ///      - If Decoy is in `record` mode:
  ///        - Converts the live response to JSON data.
  ///        - Attempts to obtain an `HTTPURLResponse` from the response or creates a default one.
  ///        - Generates a signature for the request and records the response data and metadata via Decoy's recorder.
  ///      - Completes with the live response.
  ///    - If the network request fails, completes with the encountered error.
  ///
  /// - Parameters:
  ///   - chain: The interceptor chain managing the flow of request processing.
  ///   - request: The Apollo HTTP request representing the GraphQL operation.
  ///   - response: An optional HTTP response from earlier interceptors.
  ///   - completion: A closure invoked with the final result of the request, either a `GraphQLResult` or an error.
  public func interceptAsync<Operation>(
    chain: any Apollo.RequestChain,
    request: Apollo.HTTPRequest<Operation>,
    response: Apollo.HTTPResponse<Operation>?,
    completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void
  ) where Operation : ApolloAPI.GraphQLOperation {
    guard let urlRequest = try? request.toURLRequest(), let signature = try? GraphQLSignature(urlRequest: urlRequest) else {
      completion(.failure(NSError(domain: "DecoyInterceptor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad request."])))
      return
    }

    if let stubResponse = decoy.nextQueuedResponse(for: .signature(signature)) {
      do {
        guard let data = stubResponse.data else {
          return completion(.failure(DecoyInterceptorError.recordedStubContainsNoData))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? JSONObject else {
          return completion(.failure(DecoyInterceptorError.couldNotParseToJSON))
        }

        let graphQLResponse = GraphQLResponse(operation: request.operation, body: json)
        let (result, _) = try graphQLResponse.parseResult()
        return completion(.success(result))
      } catch {
        return completion(.failure(error))
      }
    }

    guard decoy.mode != .forceOffline else {
      return chain.handleErrorAsync(
        DecoyInterceptorError.stubNotFoundInForceOfflineMode,
        request: request,
        response: response,
        completion: completion
      )
    }

    chain.proceedAsync(request: request, response: response, interceptor: self) { result in
      switch result {
      case .success(let graphQLResponse):
        guard self.decoy.mode == .record else {
          return completion(.success(graphQLResponse))
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: graphQLResponse.asJSONDictionary()) else {
          return completion(.failure(DecoyInterceptorError.couldNotParseToJSON))
        }

        let recordedResponse: HTTPURLResponse
        if let liveResponse = response?.httpResponse as? HTTPURLResponse {
          recordedResponse = liveResponse
        } else {
          recordedResponse = HTTPURLResponse(url: signature.endpoint, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        }

        do {
          let httpURLRequest = try request.toURLRequest()
          let signature = try GraphQLSignature(urlRequest: httpURLRequest)

          self.decoy.record(
            identifier: .signature(signature),
            data: jsonData,
            response: recordedResponse,
            error: nil
          )

          completion(.success(graphQLResponse))
        } catch {
          return completion(.failure(DecoyInterceptorError.invalidURLRequest))
        }
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
