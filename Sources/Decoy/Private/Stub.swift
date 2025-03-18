import Foundation

/// A data structure representing a mocked response for a specific URL.
///
/// This structure is used to store a mock for a network request, including the URL,
/// response data, HTTP metadata, and optional error information.
struct Stub {
  /// The URL to which this mock applies.
  let url: URL

  /// The mocked response details.
  let response: Response

  /// A nested structure that contains the individual components of a mocked response.
  struct Response {
    /// The mocked response data.
    ///
    /// This is typically the body of the HTTP response (e.g., JSON data) that you want to return
    /// instead of performing a live network request.
    let data: Data?

    /// The mocked HTTP URL response.
    ///
    /// This includes metadata such as the status code and headers. It allows the consumer of the response
    /// to inspect things like HTTP status.
    let urlResponse: HTTPURLResponse?

    /// An optional dictionary containing error information.
    ///
    /// This can be used to simulate an error condition by providing additional details about the error.
    let error: [String: Any]?

    /// A convenience property that attempts to decode the `data` property into a JSON object.
    ///
    /// - Returns: A JSON object (`Any`) if the data is present and can be deserialized;
    ///   otherwise, returns `nil`.
    var json: Any? {
      guard let data = data else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
  }

  /// Returns a JSON dictionary representing this `Stub`.
  ///
  /// This dictionary includes:
  /// - The URL (under the key `"url"`).
  /// - A nested dictionary under `"mock"` that contains:
  ///   - The deserialized JSON from the response data (under the key `"json"`) if available.
  ///   - The HTTP status code (under the key `"responseCode"`) if available.
  ///   - Any error information (under the key `"error"`) if available.
  var asJSON: [String: Any] {
    var jsonDict = [String: Any]()

    // Add the URL as a string.
    jsonDict["url"] = url.absoluteString

    // Build the "mock" dictionary containing response details.
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

    // Embed the mock details into the main dictionary.
    jsonDict["mock"] = mock
    return jsonDict
  }
}
