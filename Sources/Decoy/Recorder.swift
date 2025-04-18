import Foundation

/// A protocol defining an interface for recording network requests and responses.
/// Implementers are responsible for determining whether API calls should be recorded
/// and for handling the recording process.
public protocol RecorderInterface {
  /// Indicates whether API calls should be recorded.
  ///
  /// This property is typically determined by environment variables or other configuration settings.
  var shouldRecord: Bool { get }

  /// Records a network request and its associated response.
  ///
  /// - Parameters:
  ///   - identifierurl: The `Identifier` associated with the network request, either a URL or a GraphQL signature.
  ///   - data: The optional response data returned from the request.
  ///   - response: The optional `HTTPURLResponse` containing metadata such as status code.
  ///   - error: An optional `Error` encountered during the network call.
  func record(identifier: Stub.Identifier, data: Data?, response: HTTPURLResponse?, error: Error?)

  /// Used only in tests to flush the writer queue for assertions.
  func flush(completion: @escaping () -> Void)
}

/// A concrete implementation of `RecorderInterface` that captures network requests
/// and writes their details to disk via a shared writer.
///
/// The `Recorder` converts a network interaction into a stub representation and then
/// immediately writes the stub as JSON to disk. Each instance uses its own local serial
/// queue for thread safety, but file writes are synchronized using a shared global writer
/// to maintain a consistent order across multiple Recorder instances.
public class Recorder: RecorderInterface {

  /// The `ProcessInfo` instance used to retrieve environment configuration.
  private let processInfo: ProcessInfo

  /// The writer responsible for persisting recorded data to disk.
  /// This writer should enforce global synchronization to ensure writes are ordered.
  private let writer: WriterInterface

  /// A local serial queue used to synchronize the Recorder’s internal operations.
  /// Although each Recorder instance has its own queue, the file writing is coordinated via the writer.
  private let localQueue = DispatchQueue(label: "com.decoy.recorder")

  /// Initializes a new instance of `Recorder`.
  ///
  /// - Parameters:
  ///   - processInfo: An optional `ProcessInfo` instance used for reading environment variables.
  ///     Defaults to `ProcessInfo.processInfo`.
  ///   - writer: An instance conforming to `WriterInterface` responsible for file operations.
  ///     Defaults to an instance of `Writer()`.
  init(processInfo: ProcessInfo = Decoy.processInfo, writer: WriterInterface = Writer()) {
    self.processInfo = processInfo
    self.writer = writer
  }

  /// Indicates whether API calls should be recorded.
  ///
  /// The decision is based on the environment variable specified by `Decoy.Constants.mode`.
  /// If this variable equals `Decoy.Mode.record.rawValue`, recording is enabled.
  public var shouldRecord: Bool {
    processInfo.environment[Decoy.Constants.mode] == Decoy.Mode.record.rawValue
  }

  /// Records a network request and its associated response.
  ///
  /// This method converts the provided network response into a `Stub` object and
  /// immediately writes its JSON representation to disk via the shared writer.
  /// The operation is dispatched asynchronously on a private serial queue to ensure thread safety.
  ///
  /// - Parameters:
  ///   - url: The URL associated with the network request being recorded.
  ///   - data: The response data returned by the network call, if available.
  ///   - response: The URLResponse containing metadata (e.g. status code) from the network call.
  ///   - error: An error encountered during the network call.
  ///            (Currently, error information is not recorded; you can extend this as needed.)
  public func record(identifier: Stub.Identifier, data: Data?, response: HTTPURLResponse?, error: Error?) {
    localQueue.async {
      let stub = Stub(
        identifier: identifier,
        response: Stub.Response(
          data: data,
          urlResponse: response,
          error: nil // Extend error handling as needed.
        )
      )
      // Immediately append the new recording to the file using the shared writer.
      try self.writer.append(recording: stub.asJSON)
      Decoy.logInfo("Recorded decoy for: \(identifier.stringValue)")
    }
  }

  public func flush(completion: @escaping () -> Void) {
    localQueue.async {
      self.writer.flush {
        completion()
      }
    }
  }
}
