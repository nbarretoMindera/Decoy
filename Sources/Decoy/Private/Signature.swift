import Foundation

public struct GraphQLSignature: Hashable, CustomStringConvertible {
  public let operationName: String
  public let query: String
  public let variables: [String: AnyHashable]

  public var description: String {
    let querySummary = query.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .prefix(60)
    return "\(operationName)-\(querySummary)...-vars:\(variables.hashValue)"
  }

  public init(urlRequest: URLRequest) throws {
    guard let body = urlRequest.httpBody,
          let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
          let query = json["query"] as? String else {
      throw DecoyError.invalidGraphQLRequest
    }

    let opName = json["operationName"] as? String ?? "Unnamed"
    let vars = json["variables"] as? [String: Any] ?? [:]

    self.operationName = opName
    self.query = query
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    self.variables = vars.mapValues { $0 as? AnyHashable ?? "\($0)" as AnyHashable }
  }
}

enum DecoyError: Error {
  case invalidGraphQLRequest
}
