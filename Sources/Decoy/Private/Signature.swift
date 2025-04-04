import Foundation

public struct GraphQLSignature: Codable, CustomStringConvertible, Hashable {
  public let operationName: String
  public let query: String
  public let endpoint: URL
  public let variables: [String: JSONValue]

  public var description: String {
    let summary = query.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).prefix(60)
    return "\(operationName)-\(summary)"
  }

  public init(urlRequest: URLRequest) throws {
    guard let body = urlRequest.httpBody else { throw DecoyError.invalidGraphQLRequest }
    guard let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else { throw DecoyError.invalidGraphQLRequest }
    guard let query = json["query"] as? String else { throw DecoyError.invalidGraphQLRequest }
    guard let endpoint = urlRequest.url else { throw DecoyError.invalidGraphQLRequest }

    let vars = json["variables"] as? [String: Any] ?? [:]
    self.endpoint = endpoint
    self.operationName = json["operationName"] as? String ?? "Unnamed"
    self.query = query
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    var convertedVars = [String: JSONValue]()
    for (key, value) in vars {
      if let jsonValue = JSONValue.from(any: value) {
        convertedVars[key] = jsonValue
      }
    }
    self.variables = convertedVars
  }

  public init?(json: [String: Any]) {
    guard let operationName = json["operationName"] as? String,
          let query = json["query"] as? String,
          let endpoint = json["endpoint"] as? String,
          let endpointUrl = URL(string: endpoint) else { return nil }
    let vars = json["variables"] as? [String: Any] ?? [:]
    var variablesConverted = [String: JSONValue]()
    for (key, value) in vars {
      if let jsonValue = JSONValue.from(any: value) {
        variablesConverted[key] = jsonValue
      } else {
        variablesConverted[key] = .null
      }
    }
    self.endpoint = endpointUrl
    self.operationName = operationName
    self.query = query
    self.variables = variablesConverted
  }
}

enum DecoyError: Error {
  case invalidGraphQLRequest
}
