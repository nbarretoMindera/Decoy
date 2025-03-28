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
}

/// A class responsible for recording all API calls passing through Decoy's `session`.
///
/// The `Recorder` class captures network request details, including response data and errors,
/// storing them in memory and writing them to disk via a `Writer` instance.
public class Recorder: RecorderInterface {

  /// An array of recorded API interactions for the current app session.
  ///
  /// Each recorded entry is stored as a JSON dictionary containing details of the request,
  /// response, and any associated errors.
  public var recordings = [[String: Any]]()

  /// The `ProcessInfo` instance used to determine whether recording is enabled.
  private let processInfo: ProcessInfo

  /// The `WriterInterface` instance used to persist recorded requests to disk.
  private let writer: WriterInterface

  /// Initializes a new `Recorder` instance.
  ///
  /// - Parameters:
  ///   - processInfo: The `ProcessInfo` instance used to check environment variables. Defaults to `.processInfo`.
  ///   - writer: A `WriterInterface` instance responsible for writing recorded responses to disk. Defaults to `Writer()`.
  init(processInfo: ProcessInfo = .processInfo, writer: WriterInterface = Writer()) {
    self.processInfo = processInfo
    self.writer = writer
  }

  /// Determines whether Decoy is running in record mode.
  ///
  /// - Returns: `true` if Decoy is set to record network requests, otherwise `false`.
  ///
  /// This property checks the `Decoy.Constants.mode` environment variable and returns
  /// `true` if it is set to `.record`.
  var shouldRecord: Bool {
    processInfo.environment[Decoy.Constants.mode] == Decoy.Mode.record.rawValue
  }

  /// Records a network request and its associated response.
  ///
  /// - Parameters:
  ///   - url: The URL of the request being recorded.
  ///   - data: The response data returned from the request, if available.
  ///   - response: The HTTP response metadata, if available.
  ///   - error: An error object representing any failure that occurred.
  ///
  /// This method:
  /// 1. Creates a `Stub` instance representing the request and response.
  /// 2. Converts the stub into a JSON dictionary.
  /// 3. Inserts the recorded request at the beginning of the `recordings` array.
  /// 4. Attempts to persist the updated recordings to disk using `Writer`.
  func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    let stub = Stub(
      url: url,
      response: Stub.Response(
        data: data,
        urlResponse: response as? HTTPURLResponse,
        error: nil // Error handling is not implemented here, but could be extended.
      )
    )

    // Insert the new recording at the beginning of the array.
    recordings.insert(stub.asJSON, at: 0)

    // Attempt to persist the recorded interactions to disk.
    try? writer.write(recordings: recordings)
  }
}
