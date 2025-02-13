import Foundation

protocol LoaderInterface {
  func loadJSON(from url: URL) -> [MockMark]?
}

/// Simple typealiases used to make this structure cleaner to read.
private typealias MockMarkDictionary = [String: Any]
private typealias MockMarkArray = [MockMarkDictionary]

/// Used to load mocks from JSON files, and decode them.
struct Loader: LoaderInterface {

  struct Constants {
    static let url = "url"
    static let mock = "mock"
    static let json = "json"
    static let error = "error"
    static let statusCode = "statusCode"
    static let httpVersion = "httpVersion"
    static let headerFields = "headerFields"
  }

  /// Looks for a JSON file at the given URL, and decodes its contents into an array of mocked responses.
  ///
  /// - Parameters:
  ///   - url: The location at which to look for a JSON file containing ordered, mocked responses.
  ///
  /// - Returns: An optional array of `MockMark`s, read sequentially from the named JSON.
  func loadJSON(from url: URL) -> [MockMark]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? MockMarkArray else { return nil }

    return json.compactMap { mockMark(from: $0) }
  }

  private func mockMark(from json: [String: Any]) -> MockMark? {
    guard let urlString = json[Constants.url] as? String else { return nil }
    guard let url = URL(string: urlString) else { return nil }
    guard let mock = json[Constants.mock] as? MockMarkDictionary else { return nil }

    let data = data(from: mock)
    let urlResponse = urlResponse(to: url, from: mock)
    let response = MockMark.Response(data: data, urlResponse: urlResponse, error: nil)

    return MockMark(url: url, response: response)
  }

  private func data(from mock: MockMarkDictionary) -> Data? {
    guard let json = mock[Constants.json] else { return nil }
    return try? JSONSerialization.data(withJSONObject: json)
  }

  private func urlResponse(to url: URL, from mock: MockMarkDictionary) -> HTTPURLResponse? {
    HTTPURLResponse(
      url: url,
      statusCode: mock[Constants.statusCode] as? Int ?? 200,
      httpVersion: mock[Constants.httpVersion] as? String,
      headerFields: mock[Constants.headerFields] as? [String: String]
    )
  }

  private func error(from mock: MockMarkDictionary) -> [String: Any]? {
    return nil
  }
}
