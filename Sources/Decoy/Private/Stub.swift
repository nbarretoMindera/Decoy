import Foundation

public struct Stub {
  /// Represents the unique identifier for a stub.
  public enum Identifier: Hashable {
    case url(URL)
    case signature(GraphQLSignature)

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
    jsonDict["identifier"] = identifier.stringValue

    var mock = [String: Any]()
    if let data = response.data,
       let jsonObj = try? JSONSerialization.jsonObject(with: data) {
      mock["json"] = jsonObj
    }
    if let code = response.urlResponse?.statusCode {
      mock["responseCode"] = code
    }
    if let error = response.error {
      mock["error"] = error
    }
    jsonDict["mock"] = mock
    return jsonDict
  }
}
