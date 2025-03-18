import Foundation

/// A data structure representing a mocked response for a specific URL.
///
/// This struct is used to define a URL mock within the Decoy framework, allowing network requests
/// to return predefined responses instead of making actual network calls.
struct Stub {

  /// The URL to which this mock response applies.
  ///
  /// When a request is made to this URL, the associated `response` will be returned.
  let url: URL

  /// The mocked response associated with the `url`.
  ///
  /// This includes the response data, HTTP response metadata, and any mock error information.
  let response: Response

  /// A structure representing the different components of a mocked response.
  struct Response {

    /// The data payload returned by the mock response.
    ///
    /// This represents the body of the HTTP response, if applicable.
    let data: Data?

    /// The HTTP response metadata, including status code and headers.
    ///
    /// If set, this mimics the metadata of a real HTTP response.
    let urlResponse: HTTPURLResponse?

    /// A dictionary containing error information to be returned if the request fails.
    ///
    /// This can simulate network errors, API errors, or timeout scenarios.
    let error: [String: Any]?

    /// Converts the response data into a JSON object, if possible.
    ///
    /// - Returns: A JSON object (`Any`) if the data can be deserialized, otherwise `nil`.
    ///
    /// This property allows tests to easily inspect the structured content of the mock response.
    var json: Any? {
      guard let data else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
  }

  /// Encodes the `Stub` as a JSON dictionary.
  ///
  /// - Returns: A dictionary representation of the stub, including:
  ///   - `"url"`: The absolute string of the stubbed URL.
  ///   - `"mock"`: A dictionary containing:
  ///     - `"json"`: The response data converted to JSON, if available.
  ///     - `"responseCode"`: The HTTP status code, if available.
  ///     - `"error"`: Any error information associated with the stub.
  ///
  /// This method allows for easy serialization of stubbed responses, which can be written to files or logged.
  var asJSON: [String: Any] {
    var json = [String: Any]()

    json["url"] = url.absoluteString

    var mock = [String: Any]()

    if let data = response.data, let jsonObject = try? JSONSerialization.jsonObject(with: data) {
      mock["json"] = jsonObject
    }

    if let code = response.urlResponse?.statusCode {
      mock["responseCode"] = code
    }

    if let error = response.error {
      mock["error"] = error
    }

    json["mock"] = mock

    return json
  }
}
