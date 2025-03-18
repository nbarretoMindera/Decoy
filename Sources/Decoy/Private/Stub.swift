import Foundation

/// A data structure representing a mocked response for a specific URL.
struct Stub {
  /// The URL to which this mock applies.
  let url: URL
  /// The mocked response.
  let response: Response

  /// Contains the parts of the mocked response.
  struct Response {
    /// The mocked response data.
    let data: Data?
    /// The mocked HTTP response.
    let urlResponse: HTTPURLResponse?
    /// An optional error dictionary.
    let error: [String: Any]?

    /// Convenience property to decode the data into JSON.
    var json: Any? {
      guard let data = data else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
  }

  /// Returns a JSON dictionary representing this Stub.
  var asJSON: [String: Any] {
    var jsonDict = [String: Any]()
    jsonDict["url"] = url.absoluteString

    var mock = [String: Any]()
    if let data = response.data, let jsonObj = try? JSONSerialization.jsonObject(with: data) {
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
