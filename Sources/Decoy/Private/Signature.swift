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

  public static func from(urlRequest: URLRequest) throws -> GraphQLSignature {
    guard let body = urlRequest.httpBody,
          let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
          let query = json["query"] as? String else {
      throw DecoyError.invalidGraphQLRequest
    }

    let opName = json["operationName"] as? String ?? "Unnamed"
    let vars = json["variables"] as? [String: Any] ?? [:]

    return GraphQLSignature(
      operationName: opName,
      query: query.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines),
      variables: vars.mapValues { $0 as? AnyHashable ?? "\($0)" as AnyHashable }
    )
  }
}

enum DecoyError: Error {
  case invalidGraphQLRequest
}
