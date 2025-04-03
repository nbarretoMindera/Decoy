import Foundation

class MockURLProtocol: URLProtocol {
  static var dataToReturn: Data?
  var httpURLResponseToReturn: HTTPURLResponse?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    if let dataToReturn = Self.dataToReturn {
      client?.urlProtocol(self, didLoad: dataToReturn)
      client?.urlProtocolDidFinishLoading(self)
    }
  }
}
