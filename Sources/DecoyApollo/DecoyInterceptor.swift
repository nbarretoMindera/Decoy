import Apollo
import ApolloAPI
import Decoy
import Foundation

/// Potential errors returned in the case of failure.
public enum DecoyInterceptorError: Error {
  case recordedStubContainsNoData
  case couldNotParseToJSON
  case invalidURLRequest
}

/// An Apollo interceptor that integrates the Decoy mocking framework into GraphQL requests.
///
/// The DecoyInterceptor is responsible for intercepting GraphQL requests processed by Apollo. It
/// first checks the Decoy queue for a pre-loaded stub response based on the request's URL. If a stub
/// is available, it converts the stub data into a GraphQLResponse, parses the result, and returns it.
/// If no stub is available, it allows the live network request to proceed. When the live response is
/// received, if Decoy is in record mode, the interceptor records the response via the Decoy recorder.
public class DecoyInterceptor: ApolloInterceptor {

  /// A unique identifier for this interceptor.
  public var id: String {
    "DecoyInterceptor"
  }

  /// Initializes a new instance of `DecoyInterceptor`.
  public init() {}

  /// Intercepts a GraphQL request and either returns a stubbed response from the Decoy queue
  /// or lets the live network request proceed.
  ///
  /// The interceptor performs the following steps:
  ///
  /// 1. Converts the Apollo HTTPRequest to a URLRequest in order to extract the URL.
  /// 2. Checks the Decoy queue for a stub response corresponding to that URL.
  /// 3. If a stub is found:
  ///    - Deserializes the stub data into a JSON object.
  ///    - Constructs a GraphQLResponse using the operation and JSON body.
  ///    - Parses the result and completes with the stubbed response.
  /// 4. If no stub is available:
  ///    - Proceeds with the live network request by calling `chain.proceedAsync`.
  ///    - On success, if Decoy is in record mode, it converts the live response to JSON data
  ///      and records it using the Decoy recorder.
  ///    - Completes with the live response.
  ///
  /// - Parameters:
  ///   - chain: The request chain managing the flow of interceptors.
  ///   - request: The Apollo HTTPRequest representing the GraphQL operation.
  ///   - response: An optional HTTP response provided by earlier interceptors.
  ///   - completion: A closure called with the final result of the request, either a GraphQLResult or an error.
  public func interceptAsync<Operation>(
    chain: any Apollo.RequestChain,
    request: Apollo.HTTPRequest<Operation>,
    response: Apollo.HTTPResponse<Operation>?,
    completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void
  ) where Operation : ApolloAPI.GraphQLOperation {

    // Convert Apollo's HTTPRequest to a URLRequest to extract the URL.
    guard let urlRequest = try? request.toURLRequest(), let signature = try? GraphQLSignature(urlRequest: urlRequest) else {
      completion(.failure(NSError(domain: "DecoyInterceptor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad request."])))
      return
    }

    // Check the Decoy queue for a stubbed response corresponding to the URL.
    if let stubResponse = Decoy.queue.nextQueuedResponse(for: .signature(signature)) {
      do {
        // Ensure the stub response contains data.
        guard let data = stubResponse.data else {
          return completion(.failure(DecoyInterceptorError.recordedStubContainsNoData))
        }
        // Deserialize the stub data into a JSON object.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? JSONObject else {
          return completion(.failure(DecoyInterceptorError.couldNotParseToJSON))
        }
        // Construct a GraphQLResponse using the operation and JSON body.
        let graphQLResponse = GraphQLResponse(operation: request.operation, body: json)
        // Parse the GraphQLResponse to get the result.
        let (result, _) = try graphQLResponse.parseResult()
        // Complete with the stubbed result.
        return completion(.success(result))
      } catch {
        // If an error occurs during stub conversion, complete with the error.
        return completion(.failure(error))
      }
    }

    // If no stub is available, proceed with the live network request.
    chain.proceedAsync(request: request, response: response, interceptor: self) { result in
      switch result {
      case .success(let graphQLResponse):
        guard Decoy.mode() == .record else {
          return completion(.success(graphQLResponse))
        }

        // Convert the live response into JSON data.
        guard let jsonData = try? JSONSerialization.data(withJSONObject: graphQLResponse.asJSONDictionary()) else {
          return completion(.failure(DecoyInterceptorError.couldNotParseToJSON))
        }

        // Attempt to parse an HTTPURLResponse from the GraphQLResponse.
        let recordedResponse: HTTPURLResponse
        if let liveResponse = response?.httpResponse as? HTTPURLResponse {
          recordedResponse = liveResponse
        } else {
          // TODO: Should we throw an error here / complete with failure instead?
          recordedResponse = HTTPURLResponse(url: signature.endpoint, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        }

        // Generate a signature for the response so that we can access it later.
        do {
          let httpURLRequest = try request.toURLRequest()
          let signature = try GraphQLSignature(urlRequest: httpURLRequest)

          // Record the response.
          Decoy.recorder.record(
            identifier: .signature(signature),
            data: jsonData,
            response: recordedResponse,
            error: nil
          )

          // Complete with the live response.
          completion(.success(graphQLResponse))
        } catch {
          return completion(.failure(DecoyInterceptorError.invalidURLRequest))
        }
      case .failure(let error):
        // Complete with any errors encountered.
        completion(.failure(error))
      }
    }
  }
}
