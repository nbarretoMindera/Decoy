import Foundation

/// A custom URLProtocol that intercepts network requests and serves mock responses.
///
/// When a request is intercepted:
/// - If a mock is available in Decoy's queue, that response is returned.
/// - If no mock is available and the mode is liveIfUnmocked or record,
///   a live network request is performed (using a session that excludes this protocol to avoid recursion).
///   In record mode, the live response is recorded.
/// - If no mock is available in forceOffline mode, an error is returned.
///
/// This URLProtocol enables UI tests to run without requiring the app to be aware of the mocking system.
class DecoyURLProtocol: URLProtocol {
  /// Determines whether this protocol can handle the given request.
  ///
  /// - Parameter request: The URLRequest to check.
  /// - Returns: Always returns true so that all requests are intercepted.
  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  /// Returns the canonical version of the request.
  ///
  /// - Parameter request: The original URLRequest.
  /// - Returns: The canonical URLRequest (unchanged).
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  /// Starts loading the request.
  ///
  /// This method first checks for a queued mock for the request’s URL. If found, it returns the mock.
  /// Otherwise, it delegates behavior based on the current Decoy mode.
  override func startLoading() {
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

  override func stopLoading() {}
}

private extension DecoyURLProtocol {
  // MARK: - Private Helper Methods

  /// Checks the mock queue for a response for the specified URL.
  ///
  /// If a mock is found, it is sent to the client and recorded if needed.
  ///
  /// - Parameter url: The URL for which to check for a queued mock.
  /// - Returns: `true` if a mock response was found and handled; otherwise, `false`.
  func handleMockResponse(for url: URL) -> Bool {
    if let mockResponse = Decoy.queue.nextQueuedResponse(for: url) {
      if let data = mockResponse.data {
        client?.urlProtocol(self, didLoad: data)
      }
      if let urlResponse = mockResponse.urlResponse {
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
      }

      if Decoy.recorder.shouldRecord {
        Decoy.recorder.record(url: url, data: mockResponse.data, response: mockResponse.urlResponse, error: nil)
      }

      client?.urlProtocolDidFinishLoading(self)
      return true
    }
    return false
  }

  /// Performs a live network request for the given request and URL.
  ///
  /// A live URLSession is created with a configuration that excludes DecoyURLProtocol
  /// to prevent recursion. The result of the live request is passed to the client.
  /// In record mode, the live response is recorded if recording is enabled.
  ///
  /// - Parameters:
  ///   - request: The URLRequest to be executed.
  ///   - url: The URL from the request.
  func performLiveRequest(for request: URLRequest, url: URL) {
    let config = URLSessionConfiguration.default
    // Exclude DecoyURLProtocol to avoid recursive interception.
    config.protocolClasses = config.protocolClasses?.filter { $0 != DecoyURLProtocol.self }
    let liveSession = URLSession(configuration: config)

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
          Decoy.recorder.record(url: url, data: data, response: response, error: error)
        }
        self.client?.urlProtocolDidFinishLoading(self)
      }
    }
    task.resume()
  }

  /// Sends an error to the client indicating that no mock is available in forceOffline mode.
  ///
  /// - Parameter url: The URL for which no mock was available.
  func sendForceOfflineError(for url: URL) {
    let error = NSError(
      domain: "DecoyErrorDomain",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: "No mock available for URL \(url)"]
    )
    client?.urlProtocol(self, didFailWithError: error)
  }
}
