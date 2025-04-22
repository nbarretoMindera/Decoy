import Foundation

/// A custom `URLProtocol` implementation that intercepts URL requests to serve or record mock responses based on the Decoy configuration.
///
/// This protocol allows for conditional mocking of network requests, enabling tests to use predefined responses or record live network traffic.
/// It supports different modes such as live requests, recording, and forced offline behavior.
public class DecoyURLProtocol: URLProtocol {
  /// A closure that returns the `URLSession` to use for live requests.
  ///
  /// By default, this returns a session with the default configuration excluding `DecoyURLProtocol` to prevent recursive handling.
  /// This property can be overridden in tests to provide a custom or mocked `URLSession`, enabling testability of live network behavior.
  public static var liveSessionProvider: () -> URLSession = {
    let config = URLSessionConfiguration.default
    // Remove DecoyURLProtocol from the protocolClasses to prevent recursion.
    config.protocolClasses = config.protocolClasses?.filter { $0 != DecoyURLProtocol.self }
    return URLSession(configuration: config)
  }

  private static var decoyInstance: Decoy?

  /// Registers a `Decoy` instance with this protocol.
  ///
  /// This associates the given `Decoy` instance to be used for mocking and recording network requests.
  /// Typically called once during setup to enable the protocol to access mock queues and recorders.
  /// - Parameter decoy: The `Decoy` instance to register.
  public static func register(decoy: Decoy) {
    decoyInstance = decoy
  }

  /// Resets the registered `Decoy` instance.
  ///
  /// This clears any previously registered `Decoy`, effectively disabling mocking and recording until a new instance is registered.
  public static func reset() {
    decoyInstance = nil
  }

  /// Returns the currently registered `Decoy` instance.
  ///
  /// This method is used internally to access the active `Decoy` for mocking and recording.
  /// Calling this without a registered instance will cause a runtime fatal error.
  /// - Returns: The active `Decoy` instance.
  public static func currentDecoy() -> Decoy {
    guard let instance = decoyInstance else {
      fatalError("DecoyURLProtocol: No Decoy instance registered.")
    }
    return instance
  }

  /// The current mode of operation for the protocol.
  ///
  /// Determines how requests are handled: live, recorded, or forced offline.
  public static var mode: Decoy.Mode = .liveIfUnmocked

  /// Determines whether this protocol can handle the given request.
  ///
  /// This method is called by the URL loading system to decide if this protocol should intercept the request.
  /// It returns `true` if the current `Decoy` instance indicates that mocking should be applied (e.g., during UI testing).
  /// - Parameter request: The URL request to evaluate.
  /// - Returns: `true` if the protocol should handle the request; otherwise, `false`.
  public override class func canInit(with request: URLRequest) -> Bool {
    currentDecoy().isXCUI
  }

  /// Returns a canonical version of the given request.
  ///
  /// This method is called to standardize the request before handling.
  /// Here, it simply returns the request unchanged.
  /// - Parameter request: The original URL request.
  /// - Returns: The canonical URL request.
  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  /// Starts loading the request.
  ///
  /// This method is called when the protocol begins processing a request.
  /// It attempts to serve a mock response if available; otherwise, it performs a live request or sends an offline error based on the current mode.
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

  /// Stops loading the request.
  ///
  /// This method is called if the loading is cancelled or stopped.
  /// No additional cleanup is necessary here.
  public override func stopLoading() {}
}

private extension DecoyURLProtocol {
  /// Attempts to handle the request by returning a queued mock response if available.
  ///
  /// If a mock response is found in the queue for the given URL, it sends the mock data and response to the client,
  /// and records the interaction if recording is enabled.
  /// - Parameter url: The URL of the request.
  /// - Returns: `true` if a mock response was handled; otherwise, `false`.
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

  /// Performs a live network request using the live session provider.
  ///
  /// This method forwards the request to a live `URLSession` and relays the response or error back to the client.
  /// If recording is enabled, the response is recorded.
  /// - Parameters:
  ///   - request: The original URL request.
  ///   - url: The URL of the request.
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

  /// Sends a forced offline error to the client.
  ///
  /// This method is called when no mock is available and the mode is set to force offline,
  /// simulating a failure to reach the network.
  /// - Parameter url: The URL of the request.
  func sendForceOfflineError(for url: URL) {
    let error = NSError(
      domain: "DecoyErrorDomain",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: "No mock available for URL \(url)"]
    )
    client?.urlProtocol(self, didFailWithError: error)
  }
}
