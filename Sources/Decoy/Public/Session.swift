import Foundation

/// A custom URLProtocol that intercepts network requests and serves mock responses.
/// If a mock is queued, it returns that response. Otherwise, if in liveIfUnmocked mode,
/// it performs a live network request; if in forceOffline mode, it returns an error.
class DecoyURLProtocol: URLProtocol {

  override class func canInit(with request: URLRequest) -> Bool {
    // Intercept all requests.
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    // Check the mock queue for a response.
    if let mockResponse = Decoy.queue.nextQueuedResponse(for: url) {
      if let data = mockResponse.data {
        client?.urlProtocol(self, didLoad: data)
      }
      if let urlResponse = mockResponse.urlResponse {
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
      }

      // If recording is enabled, record the mocked response.
      if Decoy.recorder.shouldRecord {
        Decoy.recorder.record(url: url, data: mockResponse.data, response: mockResponse.urlResponse, error: nil)
      }

      client?.urlProtocolDidFinishLoading(self)
      return
    }

    // No mock available – decide behavior based on the Decoy mode.
    switch Decoy.mode {
    case .liveIfUnmocked, .record:
      // For both liveIfUnmocked and record modes, perform a live network request.
      // Create a URLSession configuration that does not include DecoyURLProtocol to avoid recursion.
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
          // If in record mode, record the live response.
          if Decoy.mode == .record, Decoy.recorder.shouldRecord {
            Decoy.recorder.record(url: url, data: data, response: response, error: error)
          }
          self.client?.urlProtocolDidFinishLoading(self)
        }
      }
      task.resume()

    case .forceOffline:
      // In forceOffline mode, if no mock exists, return an error.
      let error = NSError(domain: "DecoyErrorDomain",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No mock available for URL \(url)"])
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {
    // No special cleanup necessary.
  }
}

/// A subclass of `URLSession` that integrates with Decoy for request mocking and response recording.
///
/// This class wraps a `URLSession` instance, overriding `dataTask` methods to inject Decoy's mocked `DataTask` objects.
/// It also records responses if Decoy's recorder is active.
public class Session: URLSession, @unchecked Sendable {

  /// The underlying `URLSession` instance being wrapped.
  public let urlSession: URLSession

  /// The current mode of this session, determined by `ProcessInfo`.
  ///
  /// The mode is used to decide whether network calls should be mocked, recorded, or passed through as live requests.
  public let mode: Decoy.Mode

  /// The recorder responsible for capturing responses from network requests.
  ///
  /// This allows Decoy to store real responses when necessary for later playback.
  var recorder: RecorderInterface = Decoy.recorder

  /// Initializes a new `Session` instance, wrapping an existing `URLSession`.
  ///
  /// - Parameters:
  ///   - mocking: The `URLSession` instance to be wrapped. Defaults to `.shared`.
  ///   - processInfo: The `ProcessInfo` instance used to determine the Decoy mode. Defaults to `.processInfo`.
  ///
  /// The initialization reads the `Decoy.Constants.mode` environment variable to determine whether requests should
  /// be mocked, recorded, or made live. If no mode is found in the environment, it defaults to `.liveIfUnmocked`.
  required public init(mocking session: URLSession = .shared, processInfo: ProcessInfo = .processInfo) {
    self.urlSession = session
    if let modeString = processInfo.environment[Decoy.Constants.mode],
       let modeEnum = Decoy.Mode(rawValue: modeString) {
      self.mode = modeEnum
    } else {
      self.mode = .liveIfUnmocked
    }
  }
}
