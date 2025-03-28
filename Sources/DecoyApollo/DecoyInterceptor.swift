import Apollo
import ApolloAPI
import Decoy
import Foundation

public class DecoyInterceptor: ApolloInterceptor {
  public var id: String {
    "DecoyInterceptor"
  }

  public init() {}

  public func interceptAsync<Operation>(
    chain: any Apollo.RequestChain,
    request: Apollo.HTTPRequest<Operation>,
    response: Apollo.HTTPResponse<Operation>?,
    completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void
  ) where Operation : ApolloAPI.GraphQLOperation {
    // Convert Apollo's HTTPRequest to a URLRequest so we can extract the URL.
    guard let urlRequest = try? request.toURLRequest(), let url = urlRequest.url else {
      completion(
        .failure(
          NSError(
            domain: "DecoyGraphQLInterceptor",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URLRequest."]
          )
        )
      )
      return
    }

    // Try to get a stubbed response from the Decoy queue.
    if let stubResponse = Decoy.queue.nextQueuedResponse(for: url) {
      do {
        // Convert the stored stub data to a GraphQLResponse.
        guard let data = stubResponse.data else { fatalError("No data.") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? JSONObject else { fatalError("Bad data.") }
        let graphQLResponse = GraphQLResponse(operation: request.operation, body: json)
        let (result, _) = try graphQLResponse.parseResult()
        print("DecoyGraphQLInterceptor: Returning stubbed response for \(url.absoluteString)")
        completion(.success(result))
        return
      } catch {
        completion(.failure(error))
        return
      }
    }

    // If no stub is available, proceed with the live network request.
    chain.proceedAsync(request: request, response: response, interceptor: self) { result in
      switch result {
      case .success(let graphQLResponse):
        if Decoy.mode() == .record {
          guard let jsonData = try? JSONSerialization.data(withJSONObject: graphQLResponse.asJSONDictionary()) else {
            print("FAIL")
            return
          }

          Decoy.recorder.record(
            url: url,
            data: jsonData,
            response: HTTPURLResponse(
              url: url,
              statusCode: 100,
              httpVersion: nil,
              headerFields: nil
            ),
            error: nil
          )
          print("DecoyGraphQLInterceptor: Recorded live response for \(url.absoluteString)")
        }
        completion(.success(graphQLResponse))

      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
