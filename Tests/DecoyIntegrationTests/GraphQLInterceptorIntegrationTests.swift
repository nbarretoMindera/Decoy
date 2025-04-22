import Apollo
@testable import Decoy
import XCTest

class GraphQLInterceptorIntegrationTests: XCTestCase {
  var fileURL: URL!
  var processInfo: MockProcessInfo!
  var decoy: Decoy!

  override func setUpWithError() throws {
    try super.setUpWithError()

    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-mock.json")

    processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    decoy = Decoy(processInfo: processInfo)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: fileURL)
    super.tearDown()
  }

  func test_apolloClient_decoyInterceptor_recordsAndReplays() throws {
    // Initial Apollo client setup
    let store = ApolloStore()
    let client = URLSessionClient()
    let provider = TestInterceptorProvider(store: store, client: client, decoy: decoy)
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
    RecorderWaiter.waitForFlush(recorder: decoy.recorder)

    // Create a new Apollo stack with Decoy in forceOffline mode to simulate the replay.
    let processInfo2 = MockProcessInfo()
    processInfo2.mockedIsRunningXCUI = true
    processInfo2.mockedEnvironment = [
      Decoy.Constants.mode: "forceOffline",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    let decoy2 = Decoy(processInfo: processInfo2)
    let store2 = ApolloStore()
    let client2 = URLSessionClient()
    let provider2 = TestInterceptorProvider(store: store2, client: client2, decoy: decoy2)
    let transport2 = RequestChainNetworkTransport(
      interceptorProvider: provider2,
      endpointURL: URL(string: "https://example.com/graphql")!
    )
    let apollo2 = ApolloClient(networkTransport: transport2, store: store2)

    let replayExpectation = expectation(description: "Replay completes")

    apollo2.fetch(query: MockGraphQLOperation()) { result in
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

  func test_apolloClient_decoyInterceptor_recordsAndReplays_multipleRequests() throws {
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-multi-mock.json")

    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.path,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    let decoy = Decoy(processInfo: processInfo)
    let store = ApolloStore()
    let client = URLSessionClient()
    let provider = TestInterceptorProvider(store: store, client: client, decoy: decoy)
    let transport = RequestChainNetworkTransport(
      interceptorProvider: provider,
      endpointURL: URL(string: "https://example.com/graphql")!
    )
    let apollo = ApolloClient(networkTransport: transport, store: store)

    let query1 = MockGraphQLOperation(variableValues: ["var1": "value1"])
    let query2 = MockGraphQLOperation(variableValues: ["var2": "value2"])

    let recordExp1 = expectation(description: "Record query1")
    let recordExp2 = expectation(description: "Record query2")

    apollo.fetch(query: query1) { result in
      if case .failure(let error) = result {
        XCTFail("Query1 failed: \(error)")
      }
      recordExp1.fulfill()
    }

    apollo.fetch(query: query2) { result in
      if case .failure(let error) = result {
        XCTFail("Query2 failed: \(error)")
      }
      recordExp2.fulfill()
    }

    wait(for: [recordExp1, recordExp2], timeout: 5)
    RecorderWaiter.waitForFlush(recorder: decoy.recorder)

    // Create a new Apollo stack with Decoy in forceOffline mode to simulate the replay.
    let processInfo2 = MockProcessInfo()
    processInfo2.mockedIsRunningXCUI = true
    processInfo2.mockedEnvironment = [
      Decoy.Constants.mode: "forceOffline",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    let decoy2 = Decoy(processInfo: processInfo2)
    let store2 = ApolloStore()
    let client2 = URLSessionClient()
    let provider2 = TestInterceptorProvider(store: store2, client: client2, decoy: decoy2)
    let transport2 = RequestChainNetworkTransport(
      interceptorProvider: provider2,
      endpointURL: URL(string: "https://example.com/graphql")!
    )
    let apollo2 = ApolloClient(networkTransport: transport2, store: store2)

    let replayExpectation1 = expectation(description: "Replay of query 1 completes")
    let replayExpectation2 = expectation(description: "Replay of query 2 completes")

    apollo2.fetch(query: query1) { result in
      switch result {
      case .success(let result):
        XCTAssertNotNil(result.data)
      case .failure(let error):
        XCTFail("Replay query1 failed: \(error)")
      }
      replayExpectation1.fulfill()
    }

    apollo2.fetch(query: query2) { result in
      switch result {
      case .success(let result):
        XCTAssertNotNil(result.data)
      case .failure(let error):
        XCTFail("Replay query2 failed: \(error)")
      }
      replayExpectation2.fulfill()
    }

    wait(for: [replayExpectation1, replayExpectation2], timeout: 5)
  }

  func test_apolloClient_decoyInterceptor_forceOfflineFailsWithoutMock() throws {
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-forceoffline-error.json")

    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.mode: "forceOffline",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.path,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    decoy = Decoy(processInfo: processInfo)

    let store = ApolloStore()
    let client = URLSessionClient()
    let provider = TestInterceptorProvider(store: store, client: client, decoy: decoy)
    let transport = RequestChainNetworkTransport(
      interceptorProvider: provider,
      endpointURL: URL(string: "https://example.com/graphql")!
    )
    let apollo = ApolloClient(networkTransport: transport, store: store)

    let missingQuery = MockGraphQLOperation(variableValues: ["nonexistent": "true"])
    let expectation = expectation(description: "Request should fail in forceOffline without a mock")

    apollo.fetch(query: missingQuery) { result in
      switch result {
      case .success(let result):
        print(result)
        XCTFail("Expected failure, but got success")
      case .failure(let error):
        let message = String(describing: error)
        XCTAssertEqual(message, "stubNotFoundInForceOfflineMode")
      }
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 3)
  }
}
