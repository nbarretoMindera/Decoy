import Apollo
@testable import Decoy
import XCTest

class GraphQLInterceptorIntegrationTests: XCTestCase {
  var fileURL: URL!
  var processInfo: MockProcessInfo!

  override func setUpWithError() throws {
    try super.setUpWithError()

    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-mock.json")

    processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: fileURL)
    super.tearDown()
  }

  func test_apolloClient_decoyInterceptor_recordsAndReplays() throws {
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
    RecorderWaiter.waitForFlush()

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

  func test_apolloClient_decoyInterceptor_recordsAndReplays_multipleRequests() throws {
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-multi-mock.json")

    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.path,
      Decoy.Constants.mockFilename: fileURL.lastPathComponent
    ]

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)

    let store = ApolloStore()
    let client = URLSessionClient()
    let provider = TestInterceptorProvider(store: store, client: client)
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
    RecorderWaiter.waitForFlush()

    // Switch to forceOffline
    processInfo.mockedEnvironment?[Decoy.Constants.mode] = "forceOffline"
    Decoy.setUp(processInfo: processInfo)

    let replayExp1 = expectation(description: "Replay query1")
    let replayExp2 = expectation(description: "Replay query2")

    apollo.fetch(query: query1) { result in
      switch result {
      case .success(let result):
        XCTAssertNotNil(result.data)
      case .failure(let error):
        XCTFail("Replay query1 failed: \(error)")
      }
      replayExp1.fulfill()
    }

    apollo.fetch(query: query2) { result in
      switch result {
      case .success(let result):
        XCTAssertNotNil(result.data)
      case .failure(let error):
        XCTFail("Replay query2 failed: \(error)")
      }
      replayExp2.fulfill()
    }

    wait(for: [replayExp1, replayExp2], timeout: 5)
  }

  func test_apolloClient_decoyInterceptor_forceOfflineFailsWithoutMock() throws {
//    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphql-forceoffline-error.json")
//
//    processInfo.mockedEnvironment = [
//      Decoy.Constants.isXCUI: "true",
//      Decoy.Constants.mode: "forceOffline",
//      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.path,
//      Decoy.Constants.mockFilename: fileURL.lastPathComponent
//    ]
//
//    Decoy.queue.clear()
//    Decoy.setUp(processInfo: processInfo)
//
//    let store = ApolloStore()
//    let client = URLSessionClient()
//    let provider = TestInterceptorProvider(store: store, client: client)
//    let transport = RequestChainNetworkTransport(
//      interceptorProvider: provider,
//      endpointURL: URL(string: "https://example.com/graphql")!
//    )
//    let apollo = ApolloClient(networkTransport: transport, store: store)
//
//    let missingQuery = MockGraphQLOperation(variableValues: ["nonexistent": "true"])
//    let expectation = expectation(description: "Request should fail in forceOffline without a mock")
//
//    apollo.fetch(query: missingQuery) { result in
//      switch result {
//      case .success:
//        XCTFail("Expected failure, but got success")
//      case .failure(let error):
//        let message = String(describing: error)
//        XCTAssertTrue(message.contains("No mock available"), "Unexpected error: \(message)")
//      }
//      expectation.fulfill()
//    }
//
//    wait(for: [expectation], timeout: 3)
  }
}
