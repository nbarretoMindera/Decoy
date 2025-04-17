import Apollo
import ApolloAPI
@testable import Decoy
import DecoyApollo
import XCTest

class GraphQLInterceptorIntegrationTests: XCTestCase {
  func test_apolloClient_decoyInterceptorRecordsAndReplays() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-mock.json")

    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.path,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    // Clear and set up Decoy
    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)

    // Apollo client setup
    let store = ApolloStore()
    let client = URLSessionClient()
    let provider = TestInterceptorProvider(store: store, client: client)
    let transport = RequestChainNetworkTransport(
      interceptorProvider: provider,
      endpointURL: URL(string: "https://example.com/graphql")!
    )
    let apollo = ApolloClient(networkTransport: transport, store: store)

    // Run the request once to record it
    let recordExpectation = expectation(description: "Record run completes")

    apollo.fetch(query: MockGraphQLOperation()) { result in
      switch result {
      case .success(let graphQLResult):
        XCTAssertNotNil(graphQLResult.data)
      case .failure(let error):
        XCTFail("Apollo fetch (record) failed: \(error)")
      }
      recordExpectation.fulfill()
    }

    wait(for: [recordExpectation], timeout: 3)
    WriteWaiter.waitForMocksToBeWritten(at: fileURL)

    // Switch to forceOffline mode and run again
    processInfo.mockedEnvironment?[Decoy.Constants.mode] = "forceOffline"
    Decoy.setUp(processInfo: processInfo)

    let replayExpectation = expectation(description: "Replay completes")

    apollo.fetch(query: MockGraphQLOperation()) { result in
      switch result {
      case .success(let graphQLResult):
        XCTAssertNotNil(graphQLResult.data)
      case .failure(let error):
        XCTFail("Apollo fetch (replay) failed: \(error)")
      }
      replayExpectation.fulfill()
    }

    wait(for: [replayExpectation], timeout: 3)
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

final class MockGraphQLOperation: GraphQLQuery {
  typealias Data = MockSelectionSet

  static var operationName: String = "TestQuery"
  static var operationType: ApolloAPI.GraphQLOperationType = .query
  static var operationDocument: ApolloAPI.OperationDocument = OperationDocument(
    operationIdentifier: "TestQuery",
    definition: OperationDefinition("query TestQuery { testField }")
  )

  var operationName: String { Self.operationName }

  init() {}
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
    "k"
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
