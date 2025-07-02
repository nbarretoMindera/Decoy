import Foundation

/// A protocol defining a loader responsible for reading and decoding mocked responses from a JSON file.
protocol LoaderInterface {
  /// Loads a JSON file from the specified URL and decodes it into an array of `Stub` objects.
  ///
  /// - Parameter url: The URL pointing to the JSON file containing ordered mock responses.
  /// - Returns: An optional array of `Stub` instances, representing the mocked responses.
  func loadJSON(from url: URL) throws -> [Stub]?
}

/// Simple type aliases used to improve readability.
private typealias StubDictionary = [String: Any]
private typealias StubArray = [StubDictionary]

/// A struct responsible for loading mock responses from JSON files.
///
/// This struct reads a JSON file from disk, decodes its contents, and converts it into an array of
/// `Stub` objects, which can be used for network request mocking.
struct Loader: LoaderInterface {
  /// Constants used to parse JSON keys when decoding mocked responses.
  struct Constants {
    /// The key for retrieving the Identifier from the JSON.
    static let identifier = "identifier"
    /// The key for retrieving the type of Stub (URL or Signature) from the JSON.
    static let type = "type"
    /// The key for retrieving the mock response dictionary.
    static let mock = "mock"
    /// The key for retrieving JSON response data.
    static let json = "json"
    /// The key for retrieving error details.
    static let error = "error"
    /// The key for retrieving the HTTP status code.
    static let statusCode = "statusCode"
    /// The key for retrieving the HTTP version.
    static let httpVersion = "httpVersion"
    /// The key for retrieving the response header fields.
    static let headerFields = "headerFields"
  }

    enum LoaderError: Error {
    case couldNotParseStubArrayJSON
  }

  let isXCUI: Bool

  init(isXCUI: Bool) {
    self.isXCUI = isXCUI
  }

  /// Loads and decodes mocked responses from a JSON file at the specified URL.
  ///
  /// - Parameter url: The file URL pointing to the JSON mock file.
  /// - Returns: An array of `Stub` instances if decoding succeeds, otherwise `nil`.
  ///
  /// This method:
  /// 1. Reads the JSON file from the given URL.
  /// 2. Parses the JSON into an array of dictionaries.
  /// 3. Converts each dictionary into a `Stub` object.
  ///
  /// If the JSON file cannot be read or the decoding process fails, this method returns `nil`.
  func loadJSON(from url: URL) throws -> [Stub]? {
    guard isXCUI else { return nil }

    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data)
    guard let stubArray = json as? StubArray else {
      throw LoaderError.couldNotParseStubArrayJSON
    }

    return stubArray.compactMap { stub(from: $0) }
  }
}

private extension Loader {
  /// Converts a JSON dictionary into a `Stub` instance.
  ///
  /// - Parameter json: A dictionary representing a single mocked response.
  /// - Returns: A `Stub` instance if the conversion succeeds, otherwise `nil`.
  ///
  /// This method extracts:
  /// - The `url` of the request.
  /// - The mock response details (`data`, `urlResponse`, `error`).
  func stub(from json: [String: Any]) -> Stub? {
    guard let id = Stub.Identifier(json: json) else { return nil }
    guard let mock = json[Constants.mock] as? StubDictionary else { return nil }

    if case .url(let url) = id {
      let data = data(from: mock)
      let urlResponse = urlResponse(to: url, from: mock)
      let response = Stub.Response(data: data, urlResponse: urlResponse, error: error(from: mock))
      return Stub(identifier: .url(url), response: response)
    } else if case .signature(let signature) = id {
      let data = data(from: mock)
      let urlResponse = urlResponse(to: signature.endpoint, from: mock)
      let response = Stub.Response(data: data, urlResponse: urlResponse, error: error(from: mock))
      return Stub(identifier: .signature(signature), response: response)
    } else {
      return nil
    }
  }

  /// Extracts response data from a mock dictionary.
  ///
  /// - Parameter mock: A dictionary containing the mock response details.
  /// - Returns: The response data as `Data` if available, otherwise `nil`.
  ///
  /// This method attempts to serialize the `"json"` key from the mock dictionary into a `Data` object.
  func data(from mock: StubDictionary) -> Data? {
    guard let json = mock[Constants.json] else { return nil }
    return try? JSONSerialization.data(withJSONObject: json)
  }

  /// Constructs an `HTTPURLResponse` object from a mock dictionary.
  ///
  /// - Parameters:
  ///   - url: The request URL associated with the response.
  ///   - mock: A dictionary containing the response metadata.
  /// - Returns: An `HTTPURLResponse` instance with the specified status code and headers.
  ///
  /// This method extracts:
  /// - The `statusCode` (default: `200` if not specified).
  /// - The `httpVersion` (if available).
  /// - The `headerFields` dictionary (if available).
  func urlResponse(to url: URL, from mock: StubDictionary) -> HTTPURLResponse? {
    HTTPURLResponse(
      url: url,
      statusCode: mock[Constants.statusCode] as? Int ?? 200,
      httpVersion: mock[Constants.httpVersion] as? String,
      headerFields: mock[Constants.headerFields] as? [String: String]
    )
  }

  /// Extracts error information from a mock dictionary.
  ///
  /// - Parameter mock: A dictionary containing error details.
  /// - Returns: A dictionary representing the error, or `nil` if no error is specified.
  ///
  /// **Note:** This method currently returns `nil`, but can be expanded to handle structured error responses.
  func error(from mock: StubDictionary) -> [String: Any]? {
    nil
  }
}
