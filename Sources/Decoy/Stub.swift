import Foundation

/// Represents a stub used for mocking network responses in testing scenarios.
/// This struct encapsulates the unique identifier for the stub and the associated response data.
public struct Stub {
  /// Represents the unique identifier for a stub.
  ///
  /// This enum defines the type of identifier used to match requests to stubs:
  /// - `url`: Matches stubs based on a URL.
  /// - `signature`: Matches stubs based on a GraphQL signature, which includes operation details.
  public enum Identifier: Hashable {
    /// Identifier based on a URL.
    case url(URL)
    /// Identifier based on a GraphQL signature.
    case signature(GraphQLSignature)

    /// Initializes an `Identifier` from a JSON dictionary.
    ///
    /// The dictionary must contain a `"type"` key with a value of either `"url"` or `"signature"`.
    /// For `"url"`, an `"identifier"` key with a URL string is expected.
    /// For `"signature"`, a `"signature"` key containing a dictionary representing the GraphQL signature is expected.
    ///
    /// - Parameter json: A dictionary representing the identifier.
    /// - Returns: An optional `Identifier` if the dictionary contains valid data; otherwise, `nil`.
    init?(json: [String: Any]) {
      guard let type = json["type"] as? String else { return nil }

      switch type {
      case "url":
        guard let urlString = json["identifier"] as? String else { return nil }
        guard let url = URL(string: urlString) else { return nil }
        self = .url(url)
      case "signature":
        guard let signatureJson = json["signature"] as? [String: Any] else { return nil }
        guard let sig = GraphQLSignature(json: signatureJson) else { return nil }
        self = .signature(sig)
      default:
        return nil
      }
    }

    /// A readable string representation of the identifier.
    ///
    /// This string is used for logging and matching stubs.
    var stringValue: String {
      switch self {
      case .url(let url): url.absoluteString
      case .signature(let signature): signature.description
      }
    }
  }

  /// The identifier for this stub, used to match requests.
  public let identifier: Identifier
  /// The response data and metadata to return when the stub is matched.
  public let response: Response

  /// Represents the response data and metadata for a stub.
  ///
  /// This struct contains the raw data, the HTTP response metadata, and any error information.
  public struct Response {
    /// The raw response data returned by the stub.
    public let data: Data?
    /// The HTTP URL response metadata, such as status code and headers.
    let urlResponse: HTTPURLResponse?
    /// An optional error dictionary describing any error to simulate.
    let error: [String: Any]?

    /// Attempts to decode the raw `data` into a JSON object.
    ///
    /// Returns `nil` if `data` is `nil` or if decoding fails.
    var json: Any? {
      guard let data = data else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
  }

  /// Returns a JSON dictionary representing this stub.
  ///
  /// This dictionary is suitable for serializing the stub to disk.
  /// It includes the identifier details (type, identifier string, and signature if applicable)
  /// and mock metadata such as JSON response, HTTP status code, headers, and errors.
  var asJSON: [String: Any] {
    var jsonDict = [String: Any]()

    // Use the identifier's string representation.
    if case .url = identifier {
      jsonDict["type"] = "url"
    } else if case .signature(let signature) = identifier {
      jsonDict["type"] = "signature"
      jsonDict["identifier"] = signature.description
      jsonDict["signature"] = [
        "operationName": signature.operationName,
        "query": signature.query,
        "endpoint": signature.endpoint.absoluteString,
        "variables": signature.variables.mapValues { $0.description }
      ]
    } else {
      fatalError("Attempted to record a stub with an invalid identifier.")
    }
    jsonDict["identifier"] = identifier.stringValue

    var mock = [String: Any]()
    if let data = response.data, let jsonObj = try? JSONSerialization.jsonObject(with: data) {
      mock["json"] = jsonObj
    }
    if let urlResponse = response.urlResponse {
      mock["statusCode"] = urlResponse.statusCode
      mock["headerFields"] = urlResponse.allHeaderFields as? [String: String]
    }
    if let error = response.error {
      mock["error"] = error
    }
    jsonDict["mock"] = mock

    return jsonDict
  }
}
