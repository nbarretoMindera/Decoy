import Foundation

class FakeURLProtocolClient: NSObject, URLProtocolClient {
  var loadedData: Data?
  var receivedResponse: URLResponse?
  var receivedError: Error?
  var finishLoadingCalled = false

  func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {
    if loadedData == nil {
      loadedData = data
    } else {
      loadedData?.append(data)
    }
  }

  func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
    receivedResponse = response
  }

  func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) {
    receivedError = error
  }

  func urlProtocolDidFinishLoading(_ protocol: URLProtocol) {
    finishLoadingCalled = true
  }

  func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
  func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
  func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
  func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}
