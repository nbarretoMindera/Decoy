import Apollo
import ApolloAPI
import Foundation
import XCTest
@testable import Decoy
@testable import DecoyApollo

final class DecoyInterceptorTests: XCTestCase {
  private var sut: DecoyInterceptor!

  override func setUp() {
    super.setUp()
    sut = DecoyInterceptor()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func test_id() {
    XCTAssertEqual(DecoyInterceptor().id, "DecoyInterceptor")
  }

  func test_interceptAsync_shouldFail_whenRequestCannotBeConvertedToURLRequest() {
    let exp = expectation(description: "Completion")

    sut.interceptAsync(chain: MockChain(), request: badHTTPRequest, response: nil) { result in
      if case .success = result { return XCTFail("Should've failed.") }
      exp.fulfill()
    }
    wait(for: [exp], timeout: 1)
  }

  func test_interceptAsync_shouldFail_whenStubbedResponseContainsNoData() {
    let exp = expectation(description: "Completion")
    let queue = MockQueue()
    queue.queuedResponses = [
      URL(string: "https://totally.real/endpoint")!: [Stub.Response(data: nil, urlResponse: nil, error: nil)]
    ]
    Decoy.queue = queue

    sut.interceptAsync(chain: MockChain(), request: goodHTTPRequest, response: nil) { result in
      if case .success = result {
        return XCTFail("Should've failed.")
      }

      if case .failure(let error) = result {
        XCTAssert(error as? DecoyInterceptorError == DecoyInterceptorError.recordedStubContainsNoData)
      }

      exp.fulfill()
    }
    wait(for: [exp], timeout: 1)
  }

  func test_interceptAsync_shouldFail_whenStubbedResponseDataCouldNotBeParsedToJSON() {
    let exp = expectation(description: "Completion")
    let queue = MockQueue()
    queue.queuedResponses = [
      URL(string: "https://totally.real/endpoint")!: [Stub.Response(data: "🚽".data(using: .utf8), urlResponse: nil, error: nil)]
    ]
    Decoy.queue = queue

    sut.interceptAsync(chain: MockChain(), request: goodHTTPRequest, response: nil) { result in
      if case .success = result {
        return XCTFail("Should've failed.")
      }

      if case .failure(let error) = result {
        XCTAssert(error as? DecoyInterceptorError == DecoyInterceptorError.couldNotParseToJSON)
      }

      exp.fulfill()
    }
    wait(for: [exp], timeout: 1)
  }

  func test_interceptAsync_shouldSucceed_whenJSONIsValidAndCanBeParsedBackIntoGraphQLResponse() {
    let exp = expectation(description: "Completion")
    let queue = MockQueue()
    queue.queuedResponses = [
      URL(string: "https://totally.real/endpoint")!: [Stub.Response(
        data: "{\"data\": {\"a\": \"b\"}}".data(using: .utf8),
        urlResponse: nil,
        error: nil
      )]
    ]
    Decoy.queue = queue

    sut.interceptAsync(chain: MockChain(), request: goodHTTPRequest, response: nil) { result in
      if case .success(let gqlResult) = result {
        XCTAssertEqual((gqlResult.data)?.__data._data["a"] as? String, "b")
      }

      if case .failure = result {
        return XCTFail("Should've succeeded.")
      }

      exp.fulfill()
    }
    wait(for: [exp], timeout: 1)
  }
}

private extension DecoyInterceptorTests {
  var badHTTPRequest: BadHTTPRequest<MockGraphQLOperation> {
    BadHTTPRequest(
      graphQLEndpoint: URL(string: "💩")!,
      operation: MockGraphQLOperation(),
      contentType: "A",
      clientName: "B",
      clientVersion: "C",
      additionalHeaders: [:]
    )
  }

  var goodHTTPRequest: HTTPRequest<MockGraphQLOperation> {
    Apollo.HTTPRequest(
      graphQLEndpoint: URL(string: "https://totally.real/endpoint")!,
      operation: MockGraphQLOperation(),
      contentType: "A",
      clientName: "B",
      clientVersion: "C",
      additionalHeaders: [:]
    )
  }
}

private class MockGraphQLOperation: GraphQLOperation {
  typealias Data = MockRootSelectionSet
  static var operationName: String = "ABC"
  static var operationType: ApolloAPI.GraphQLOperationType = .query
  static var operationDocument: ApolloAPI.OperationDocument = OperationDocument(
    operationIdentifier: "ABC",
    definition: OperationDefinition("DEF")
  )
}

private class MockChain: RequestChain {
  func kickoff<Operation>(request: Apollo.HTTPRequest<Operation>, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  func proceedAsync<Operation>(request: Apollo.HTTPRequest<Operation>, response: Apollo.HTTPResponse<Operation>?, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  func proceedAsync<Operation>(request: Apollo.HTTPRequest<Operation>, response: Apollo.HTTPResponse<Operation>?, interceptor: any Apollo.ApolloInterceptor, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  func cancel() {}
  func retry<Operation>(request: Apollo.HTTPRequest<Operation>, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  func handleErrorAsync<Operation>(_ error: any Error, request: Apollo.HTTPRequest<Operation>, response: Apollo.HTTPResponse<Operation>?, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  func returnValueAsync<Operation>(for request: Apollo.HTTPRequest<Operation>, value: Apollo.GraphQLResult<Operation.Data>, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {}
  
  var isCancelled: Bool = false
}

class MockRootSelectionSet: RootSelectionSet {
  required init(_dataDict: ApolloAPI.DataDict) {}
  typealias Schema = MockSchemaMetadata
  static var __parentType: any ApolloAPI.ParentType = MockParentType()
  var __data: ApolloAPI.DataDict { DataDict(data: ["a": "b"], fulfilledFragments: []) }
  static var selections: [Selection] { [Selection.field("a", String.self)] }
}

class MockParentType: ParentType {
  func canBeConverted(from objectType: ApolloAPI.Object) -> Bool { true }
  var __typename: String = "A"
}

class MockSchemaMetadata: SchemaMetadata {
  static var configuration: any ApolloAPI.SchemaConfiguration.Type = MockSchemaConfiguration.self
  static func objectType(forTypename typename: String) -> ApolloAPI.Object? { nil }
}

class MockSchemaConfiguration: SchemaConfiguration {
  static func cacheKeyInfo(for type: ApolloAPI.Object, object: ApolloAPI.ObjectData) -> ApolloAPI.CacheKeyInfo? { nil }
}

class BadHTTPRequest<Operation: GraphQLOperation>: Apollo.HTTPRequest<Operation> {
  override func toURLRequest() throws -> URLRequest {
    throw NSError(domain: "Fake", code: 999, userInfo: nil)
  }
}

class MockQueue: QueueInterface {
  var queuedResponses: [URL : [Stub.Response]] = [:]
  func queue(stub: Stub) {}
  func nextQueuedResponse(for url: URL) -> Stub.Response? {
    guard !queuedResponses.isEmpty else { return nil }
    return queuedResponses.first { $0.key == url }?.value.first
  }
}
