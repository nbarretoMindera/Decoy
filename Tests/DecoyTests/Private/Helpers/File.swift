@testable import Decoy
import XCTest

extension XCTestCase {
  var testSignature: GraphQLSignature! {
    var request = URLRequest(url: URL(string: "graph://ql")!)
    request.httpBody = "{\"query\": \"query {foo}\", \"operationName\": \"bar\", \"endpoint\": \"graph://ql\"}".data(using: .utf8)!
    return try? GraphQLSignature(urlRequest: request)
  }
}
