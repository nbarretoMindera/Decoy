import Foundation

/// A protocol defining a writer responsible for persisting recorded data.
/// Conforming types must provide a method to append a single recording (represented as a JSON dictionary)
/// to a persistent store.
protocol WriterInterface {
  /// Appends a single recording to the persistent file.
  ///
  /// - Parameter recording: A dictionary representation of a recorded network interaction.
  /// - Throws: An error if appending the recording fails (for example, due to a missing file path or serialization issues).
  func append(recording: [String: Any]) throws
}

/// An enumeration of possible errors encountered during file write operations.
enum WriterError: Error {
  /// Thrown when the required file path or filename is missing from the environment configuration.
  case filePathNotFound
  /// Thrown when JSON serialization of the recordings fails.
  case couldNotSerializeJSON
}

/// A concrete implementation of `WriterInterface` that persists recordings to a JSON file.
///
/// This implementation uses a shared global serial dispatch queue to synchronize file write operations,
/// ensuring that multiple concurrent writes from different Recorder instances are processed in order.
/// The file path and filename are determined by environment variables.
class Writer: WriterInterface {
  /// The `ProcessInfo` instance used to access environment variables.
  private let processInfo: ProcessInfo

  /// The `FileManager` instance used for performing file system operations.
  private let fileManager: FileManager

  /// A shared global serial dispatch queue used to synchronize file write operations across all `Writer` instances.
  private static let globalQueue = DispatchQueue(label: "com.yourapp.globalWriterQueue")

  /// Initializes a new `Writer` instance.
  ///
  /// - Parameters:
  ///   - processInfo: The `ProcessInfo` instance used for reading environment variables.
  ///                  Defaults to `ProcessInfo.processInfo`.
  ///   - fileManager: The `FileManager` instance used for performing file operations.
  ///                  Defaults to `FileManager.default`.
  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  /// Appends a single recording to the JSON file.
  ///
  /// This method synchronously executes on a shared global queue to ensure that writes are performed in order.
  /// It retrieves the file path and filename from environment variables, reads any existing recordings,
  /// appends the new recording, serializes the combined array to JSON, and writes it to disk.
  ///
  /// - Parameter recording: A dictionary representing a single recorded network interaction.
  /// - Throws: `WriterError.filePathNotFound` if the environment does not specify a valid file path or filename.
  ///           `WriterError.couldNotSerializeJSON` if the recordings cannot be serialized into JSON.
  func append(recording: [String: Any]) throws {
    try Writer.globalQueue.sync {
      // Retrieve the file path and filename from environment variables.
      guard let path = self.path, let file = self.file else {
        throw WriterError.filePathNotFound
      }

      // Construct the file URL where recordings will be stored.
      var url = URL(fileURLWithPath: path, isDirectory: true)
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
      url.appendPathComponent(file)
      url.deletePathExtension()
      url.appendPathExtension("json")

      // Read any existing recordings from the file.
      var existingRecordings = [[String: Any]]()
      if fileManager.fileExists(atPath: url.path),
         let data = try? Data(contentsOf: url),
         let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        existingRecordings = jsonArray
      }

      // Append the new recording to the existing recordings.
      existingRecordings.append(recording)

      // Serialize the merged array to JSON data.
      guard let jsonData = try? JSONSerialization.data(withJSONObject: existingRecordings) else {
        throw WriterError.couldNotSerializeJSON
      }

      // Write the JSON data to disk, overwriting the file.
      try jsonData.write(to: url)
      Decoy.logInfo("Wrote recording for \(recording["url"])")
    }
  }
}

/// A private extension for `Writer` that provides computed properties for retrieving
/// the file path and filename from the environment variables.
private extension Writer {
  /// Retrieves the directory path from the environment variable specified by `Decoy.Constants.mockDirectory`.
  var path: String? {
    processInfo.environment[Decoy.Constants.mockDirectory]
  }

  /// Retrieves the filename from the environment variable specified by `Decoy.Constants.mockFilename`.
  var file: String? {
    processInfo.environment[Decoy.Constants.mockFilename]
  }
}
