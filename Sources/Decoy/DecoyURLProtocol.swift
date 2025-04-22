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

  private static var decoyInstance: Decoy?

  public static func register(decoy: Decoy) {
    decoyInstance = decoy
  }

  public static func reset() {
    decoyInstance = nil
  }

  public static func currentDecoy() -> Decoy {
    guard let instance = decoyInstance else {
      fatalError("DecoyURLProtocol: No Decoy instance registered.")
    }
    return instance
  }

  public static var mode: Decoy.Mode = .liveIfUnmocked

  public override class func canInit(with request: URLRequest) -> Bool {
    currentDecoy().isXCUI
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
    switch DecoyURLProtocol.currentDecoy().mode {
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
    let decoy = DecoyURLProtocol.currentDecoy()

    if let mockResponse = decoy.queue.nextQueuedResponse(for: .url(url)) {
      if let data = mockResponse.data {
        client?.urlProtocol(self, didLoad: data)
      }
      if let urlResponse = mockResponse.urlResponse {
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
      }

      if decoy.recorder.shouldRecord {
        decoy.recorder.record(identifier: .url(url), data: mockResponse.data, response: mockResponse.urlResponse, error: nil)
      }

      client?.urlProtocolDidFinishLoading(self)
      return true
    }
    return false
  }

  func performLiveRequest(for request: URLRequest, url: URL) {
    let decoy = DecoyURLProtocol.currentDecoy()

    let liveSession = DecoyURLProtocol.liveSessionProvider()

    let task = liveSession.dataTask(with: request) { data, response, error in
      if let response = response {
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      }
      if let data = data {
        self.client?.urlProtocol(self, didLoad: data)
      }
      if let error = error {
        self.client?.urlProtocol(self, didFailWithError: error)
      } else {
        self.client?.urlProtocolDidFinishLoading(self)
      }

      // Record the response if in record mode
      if decoy.mode == .record {
        decoy.recorder.record(identifier: .url(url), data: data, response: response as? HTTPURLResponse, error: error)
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
