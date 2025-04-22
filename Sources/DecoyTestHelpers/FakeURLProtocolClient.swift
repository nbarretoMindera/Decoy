import Foundation

public class FakeURLProtocolClient: NSObject, URLProtocolClient {
  public var loadedData: Data?
  public var receivedResponse: URLResponse?
  public var receivedError: Error?
  public var finishLoadingCalled = false

  public func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {
    if loadedData == nil {
      loadedData = data
    } else {
      loadedData?.append(data)
    }
  }

  public func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
    receivedResponse = response
  }

  public func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) {
    receivedError = error
  }

  public func urlProtocolDidFinishLoading(_ protocol: URLProtocol) {
    finishLoadingCalled = true
  }

  public func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
  public func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
  public func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
  public func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}
