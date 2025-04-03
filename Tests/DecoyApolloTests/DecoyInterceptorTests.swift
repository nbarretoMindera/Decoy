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

  var didProceedAsync = false
  func proceedAsync<Operation>(request: Apollo.HTTPRequest<Operation>, response: Apollo.HTTPResponse<Operation>?, interceptor: any Apollo.ApolloInterceptor, completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) where Operation : ApolloAPI.GraphQLOperation {
    didProceedAsync = true
    completion(
      .failure(TestError.generic)
    )
  }

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
  var queuedResponses: [Stub.Identifier : [Stub.Response]] = [:]
  func queue(stub: Stub) {}
  func nextQueuedResponse(for identifier: Stub.Identifier) -> Stub.Response? {
    guard !queuedResponses.isEmpty else { return nil }
    return queuedResponses[identifier]?.first
  }
  func clear() {}
}

enum TestError: Error {
  case generic
}
