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
    // Intercept all requests.
    return true
  }

  /// Returns the canonical version of the request.
  ///
  /// - Parameter request: The original URLRequest.
  /// - Returns: The canonical URLRequest (in this case, unchanged).
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  /// Starts loading the request.
  ///
  /// This method checks for a queued mock for the request’s URL. If one is found,
  /// it returns that mock to the client. Otherwise, behavior depends on the current Decoy mode:
  /// - In liveIfUnmocked and record modes, a live network request is performed.
  ///   In record mode, the live response is recorded.
  /// - In forceOffline mode, an error is returned.
  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    // Check the mock queue for a response.
    if let mockResponse = Decoy.queue.nextQueuedResponse(for: url) {
      // Deliver the mock data if available.
      if let data = mockResponse.data {
        client?.urlProtocol(self, didLoad: data)
      }
      // Deliver the mock URL response if available.
      if let urlResponse = mockResponse.urlResponse {
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
      }

      // Record the mock response if recording is enabled.
      if Decoy.recorder.shouldRecord {
        Decoy.recorder.record(url: url, data: mockResponse.data, response: mockResponse.urlResponse, error: nil)
      }

      client?.urlProtocolDidFinishLoading(self)
      return
    }

    // No mock available – determine behavior based on Decoy mode.
    switch Decoy.mode {
    case .liveIfUnmocked, .record:
      // For liveIfUnmocked and record modes, perform a live network request.
      // Create a session configuration that excludes DecoyURLProtocol to avoid recursion.
      let config = URLSessionConfiguration.default
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
          // In record mode, record the live response if recording is enabled.
          if Decoy.mode == .record, Decoy.recorder.shouldRecord {
            Decoy.recorder.record(url: url, data: data, response: response, error: error)
          }
          self.client?.urlProtocolDidFinishLoading(self)
        }
      }
      task.resume()

    case .forceOffline:
      // In forceOffline mode, if no mock exists, immediately return an error.
      let error = NSError(domain: "DecoyErrorDomain",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No mock available for URL \(url)"])
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
}
