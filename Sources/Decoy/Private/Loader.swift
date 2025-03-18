import Foundation

protocol LoaderInterface {
  func loadJSON(from url: URL) -> [Stub]?
}

/// Simple typealiases used to make this structure cleaner to read.
private typealias StubDictionary = [String: Any]
private typealias StubArray = [StubDictionary]

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
  /// - Returns: An optional array of `Stub`s, read sequentially from the named JSON.
  func loadJSON(from url: URL) -> [Stub]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? StubArray else { return nil }

    return json.compactMap { stub(from: $0) }
  }

  private func stub(from json: [String: Any]) -> Stub? {
    guard let urlString = json[Constants.url] as? String else { return nil }
    guard let url = URL(string: urlString) else { return nil }
    guard let mock = json[Constants.mock] as? StubDictionary else { return nil }

    let data = data(from: mock)
    let urlResponse = urlResponse(to: url, from: mock)
    let response = Stub.Response(data: data, urlResponse: urlResponse, error: error(from: mock))

    return Stub(url: url, response: response)
  }

  private func data(from mock: StubDictionary) -> Data? {
    guard let json = mock[Constants.json] else { return nil }
    return try? JSONSerialization.data(withJSONObject: json)
  }

  private func urlResponse(to url: URL, from mock: StubDictionary) -> HTTPURLResponse? {
    HTTPURLResponse(
      url: url,
      statusCode: mock[Constants.statusCode] as? Int ?? 200,
      httpVersion: mock[Constants.httpVersion] as? String,
      headerFields: mock[Constants.headerFields] as? [String: String]
    )
  }

  private func error(from mock: StubDictionary) -> [String: Any]? {
    return nil
  }
}
