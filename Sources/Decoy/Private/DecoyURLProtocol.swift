import Foundation

public class DecoyURLProtocol: URLProtocol {
  /// A closure that returns the URLSession to use for live requests.
  /// In production, this returns a session with the default configuration (excluding DecoyURLProtocol).
  /// In tests, you can override this to return a custom or mocked session.
  public static var liveSessionProvider: () -> URLSession = {
    let config = URLSessionConfiguration.default
    // Remove DecoyURLProtocol from the protocolClasses to prevent recursion.
    config.protocolClasses = config.protocolClasses?.filter { $0 != DecoyURLProtocol.self }
    return URLSession(configuration: config)
  }

  public override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  public override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    // First, attempt to handle the request with a queued mock.
    if handleMockResponse(for: url) { return }

    // No mock available – decide behavior based on Decoy mode.
    switch Decoy.mode() {
    case .liveIfUnmocked, .record:
      performLiveRequest(for: request, url: url)
    case .forceOffline:
      sendForceOfflineError(for: url)
    }
  }

  public override func stopLoading() {}
}

private extension DecoyURLProtocol {
  func handleMockResponse(for url: URL) -> Bool {
    if let mockResponse = Decoy.queue.nextQueuedResponse(for: .url(url)) {
      if let data = mockResponse.data {
        client?.urlProtocol(self, didLoad: data)
      }
      if let urlResponse = mockResponse.urlResponse {
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
      }

      if Decoy.recorder.shouldRecord {
        Decoy.recorder.record(identifier: .url(url), data: mockResponse.data, response: mockResponse.urlResponse, error: nil)
      }

      client?.urlProtocolDidFinishLoading(self)
      return true
    }
    return false
  }

  func performLiveRequest(for request: URLRequest, url: URL) {
    let liveSession = DecoyURLProtocol.liveSessionProvider()

    let task = liveSession.dataTask(with: request) { data, response, error in
      if let error = error {
        self.client?.urlProtocol(self, didFailWithError: error)
      } else {
        if let response = response {
          self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = data {
          self.client?.urlProtocol(self, didLoad: data)
        }
        if Decoy.mode() == .record, Decoy.recorder.shouldRecord {
          Decoy.recorder.record(identifier: .url(url), data: data, response: response, error: error)
        }
        self.client?.urlProtocolDidFinishLoading(self)
      }
    }
    task.resume()
  }

  func sendForceOfflineError(for url: URL) {
    let error = NSError(
      domain: "DecoyErrorDomain",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: "No mock available for URL \(url)"]
    )
    client?.urlProtocol(self, didFailWithError: error)
  }
}
