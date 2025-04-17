import Foundation

class MockURLProtocol: URLProtocol {
  static var dataToReturn: Data?
  static var httpURLResponseToReturn: HTTPURLResponse?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    if let response = Self.httpURLResponseToReturn {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    if let data = Self.dataToReturn {
      client?.urlProtocol(self, didLoad: data)
    }

    client?.urlProtocolDidFinishLoading(self)
  }
}
