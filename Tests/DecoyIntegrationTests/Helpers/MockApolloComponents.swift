import Apollo
import ApolloAPI
import DecoyApollo
import Foundation

final class MockGraphQLOperation: GraphQLQuery {
  typealias Data = MockSelectionSet

  static var operationName: String = "TestQuery"
  static var operationType: ApolloAPI.GraphQLOperationType = .query
  static var operationDocument: ApolloAPI.OperationDocument = OperationDocument(
    operationIdentifier: "TestQuery",
    definition: OperationDefinition("query TestQuery { testField }")
  )

  private let _variables: [String: any ApolloAPI.JSONEncodable]

  var variables: [String: any ApolloAPI.JSONEncodable] {
    return _variables
  }

  var operationName: String { Self.operationName }

  init(variableValues: [String: any ApolloAPI.JSONEncodable] = [:]) {
    self._variables = variableValues
  }
}

final class MockSelectionSet: RootSelectionSet {
  typealias Schema = MockSchemaMetadata
  static var __parentType: any ApolloAPI.ParentType = MockParentType()
  var __data: ApolloAPI.DataDict

  required init(_dataDict: ApolloAPI.DataDict) {
    self.__data = _dataDict
  }

  static var selections: [Selection] {
    [Selection.field("testField", String.self)]
  }
}

final class MockParentType: ParentType {
  var __typename: String = "Query"
  func canBeConverted(from objectType: ApolloAPI.Object) -> Bool { true }
}

final class MockSchemaMetadata: SchemaMetadata {
  static var configuration: any SchemaConfiguration.Type = MockSchemaConfiguration.self
  static func objectType(forTypename typename: String) -> ApolloAPI.Object? { nil }
}

final class MockSchemaConfiguration: SchemaConfiguration {
  static func cacheKeyInfo(for type: ApolloAPI.Object, object: ApolloAPI.ObjectData) -> CacheKeyInfo? { nil }
}

final class MockNetworkFetchInterceptor: ApolloInterceptor {
  var id: String {
    UUID().uuidString
  }

  func interceptAsync<Operation>(
    chain: RequestChain,
    request: HTTPRequest<Operation>,
    response: HTTPResponse<Operation>?,
    completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
  ) where Operation: GraphQLOperation {
    let json: JSONObject = ["data": ["testField": "stubbed-value"]]
    let graphQLResponse = GraphQLResponse(operation: request.operation, body: json)
    do {
      let (result, _) = try graphQLResponse.parseResult()
      completion(.success(result))
    } catch {
      completion(.failure(error))
    }
  }
}

final class TestInterceptorProvider: InterceptorProvider {
  let store: ApolloStore
  let client: URLSessionClient

  init(store: ApolloStore, client: URLSessionClient) {
    self.store = store
    self.client = client
  }

  func interceptors<Operation: GraphQLOperation>(
    for operation: Operation
  ) -> [ApolloInterceptor] {
    return [
      DecoyInterceptor(),
      MockNetworkFetchInterceptor(),
      MaxRetryInterceptor(),
      CacheReadInterceptor(store: store),
      NetworkFetchInterceptor(client: client),
      ResponseCodeInterceptor(),
      JSONResponseParsingInterceptor(),
      AutomaticPersistedQueryInterceptor(),
      CacheWriteInterceptor(store: store)
    ]
  }
}
