import Foundation

/// Represents a unique fingerprint of a GraphQL request used for mocking and comparison.
///
/// This structure captures the essential components of a GraphQL operation,
/// including the operation name, query string, endpoint URL, and variables.
/// It is designed to provide a consistent and comparable signature for GraphQL requests,
/// facilitating tasks such as request matching and response mocking.
public struct GraphQLSignature: Codable, CustomStringConvertible, Hashable {
  /// The name of the GraphQL operation.
  ///
  /// This typically corresponds to the operation's defined name in the query or mutation.
  /// It helps identify the specific operation being performed.
  public let operationName: String
  
  /// The GraphQL query string.
  ///
  /// This is the actual query or mutation text sent to the GraphQL server,
  /// normalized by removing excess whitespace for consistent comparison.
  public let query: String
  
  /// The full URL of the GraphQL endpoint where the operation was sent.
  ///
  /// While many GraphQL servers use the same endpoint for all queries,
  /// this field helps distinguish requests across different environments or base URLs.
  public let endpoint: URL
  
  /// The variables provided with the GraphQL operation.
  ///
  /// These are key-value pairs representing dynamic inputs to the query or mutation.
  /// Capturing variables is essential for uniquely identifying the request signature.
  public let variables: [String: JSONValue]

  /// A human-readable signature string combining the operation name and variables.
  ///
  /// This string is useful for generating file names or matching signatures
  /// in mocking frameworks. Variables are concatenated as key-value pairs separated by underscores.
  public var description: String {
    let formattedVariables = variables
      .map { "\($0.key)-\($0.value.description)" }
      .joined(separator: "_")
    return "\(operationName)_\(formattedVariables)"
  }

  /// Creates a `GraphQLSignature` by parsing a `URLRequest` containing a GraphQL operation.
  ///
  /// - Parameter urlRequest: The URL request expected to contain a GraphQL JSON body.
  /// - Throws: `DecoyError.invalidGraphQLRequest` if the request does not contain valid GraphQL data.
  ///
  /// The initializer extracts the HTTP body, parses it as JSON, and extracts the `query`,
  /// `operationName`, and `variables` fields. It also captures the request's URL as the endpoint.
  /// The query string is normalized by collapsing whitespace and trimming.
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
      if let jsonValue = JSONValue(json: value) {
        convertedVars[key] = jsonValue
      }
    }
    self.variables = convertedVars
  }

  /// Creates a `GraphQLSignature` from a JSON dictionary representation.
  ///
  /// - Parameter json: A dictionary expected to contain keys `operationName`, `query`, `endpoint`, and optionally `variables`.
  /// - Returns: An optional `GraphQLSignature` if all required fields are present and valid.
  ///
  /// The initializer parses the endpoint URL string and converts variables into `JSONValue` instances,
  /// defaulting to `.null` for unrecognized values.
  public init?(json: [String: Any]) {
    guard let operationName = json["operationName"] as? String,
          let query = json["query"] as? String,
          let endpoint = json["endpoint"] as? String,
          let endpointUrl = URL(string: endpoint) else { return nil }
    let vars = json["variables"] as? [String: Any] ?? [:]
    var variablesConverted = [String: JSONValue]()
    for (key, value) in vars {
      if let jsonValue = JSONValue(json: value) {
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

/// Errors that can occur while parsing or handling GraphQL requests.
enum DecoyError: Error {
  /// Indicates that the provided request is not a valid GraphQL request.
  ///
  /// This error is thrown when required fields are missing,
  /// the body cannot be parsed as JSON, or the URL is invalid.
  case invalidGraphQLRequest
}
