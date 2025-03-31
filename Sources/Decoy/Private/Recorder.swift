import Foundation

/// A protocol defining a recorder for tracking API calls in Decoy.
///
/// Implementations of this protocol store network request recordings and determine
/// whether recording should occur based on the application's execution environment.
public protocol RecorderInterface {

  /// An array of recorded API interactions, stored as dictionaries.
  ///
  /// Each entry contains details of a single network request, including its URL,
  /// response data, status code, and any error information.
  var recordings: [[String: Any]] { get set }

  /// Indicates whether API calls should be recorded.
  ///
  /// This property is determined based on environment variables, allowing tests to enable or disable recording.
  var shouldRecord: Bool { get }

  /// Records a network request and its associated response.
  ///
  /// - Parameters:
  ///   - url: The `URL` for the network request being recorded.
  ///   - data: The optional response data returned by the request.
  ///   - response: The optional `URLResponse` returned by the request.
  ///   - error: The optional error encountered during the request.
  func record(url: URL, data: Data?, response: URLResponse?, error: Error?)

  func flush()
}

/// A class responsible for recording all API calls passing through Decoy's `session`.
///
/// The `Recorder` class captures network request details, including response data and errors,
/// storing them in memory and writing them to disk via a `Writer` instance.
public class Recorder: RecorderInterface {

  public var recordings = [[String: Any]]()

  private let processInfo: ProcessInfo
  private let writer: WriterInterface
  // Use a serial queue to synchronize access.
  private let syncQueue = DispatchQueue(label: "com.yourapp.recorderQueue")

  init(processInfo: ProcessInfo = .processInfo, writer: WriterInterface = Writer()) {
    self.processInfo = processInfo
    self.writer = writer
  }

  public var shouldRecord: Bool {
    processInfo.environment[Decoy.Constants.mode] == Decoy.Mode.record.rawValue
  }

  public func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    // Instead of writing on every record, just accumulate the recording.
    syncQueue.async {
      let stub = Stub(
        url: url,
        response: Stub.Response(
          data: data,
          urlResponse: response as? HTTPURLResponse,
          error: nil // You can extend error handling as needed.
        )
      )
      self.recordings.insert(stub.asJSON, at: 0)
    }
  }

  /// Flush all buffered recordings to disk.
  public func flush() {
    syncQueue.sync {
      // This call will merge with any existing file content as defined in your Writer.
      try? self.writer.write(recordings: self.recordings)
    }
  }
}
