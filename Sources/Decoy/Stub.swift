import Foundation

public struct Stub {
  /// Represents the unique identifier for a stub.
  public enum Identifier: Hashable {
    case url(URL)
    case signature(GraphQLSignature)

    init?(json: [String: Any]) {
      guard let type = json["type"] as? String else { return nil }

      switch type {
      case "url":
        guard let urlString = json["identifier"] as? String else { return nil }
        guard let url = URL(string: urlString) else { return nil }
        self = .url(url)
      case "signature":
        guard let signatureJSON = json["identifier"] as? [String: Any] else { return nil }
        guard let signature = GraphQLSignature(json: signatureJSON) else { return nil }
        self = .signature(signature)
      default:
        return nil
      }
    }

    var stringValue: String {
      switch self {
      case .url(let url): url.absoluteString
      case .signature(let signature): signature.description
      }
    }
  }

  /// The identifier for this stub.
  public let identifier: Identifier
  public let response: Response

  public struct Response {
    public let data: Data?
    let urlResponse: HTTPURLResponse?
    let error: [String: Any]?

    /// Attempts to decode `data` into a JSON object.
    var json: Any? {
      guard let data = data else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
  }

  /// Returns a JSON dictionary representing this stub.
  var asJSON: [String: Any] {
    var jsonDict = [String: Any]()

    // Use the identifier's string representation.
    if case .url = identifier {
      jsonDict["type"] = "url"
    } else if case .signature(let graphQLSignature) = identifier {
      jsonDict["type"] = "signature"
      jsonDict["endpoint"] = graphQLSignature.endpoint
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
