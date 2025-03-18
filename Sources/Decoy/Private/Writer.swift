import Compression
import Foundation

/// A protocol defining a writer that stores recorded data.
///
/// Implementations of this protocol are responsible for writing serialized JSON recordings
/// to a file system location determined by environment variables.
protocol WriterInterface {

  /// Writes an array of recordings to a file.
  ///
  /// - Parameter recordings: A collection of dictionaries representing recorded data.
  /// - Throws: A `WriterError` if the file path is missing or if JSON serialization fails.
  func write(recordings: [[String: Any]]) throws
}

/// An enumeration defining possible errors encountered during the writing process.
enum WriterError: Error {
  /// Indicates that the file path or filename was not found in the environment variables.
  case filePathNotFound
  /// Indicates that JSON serialization of the provided recordings failed.
  case couldNotSerializeJSON
}

/// A class responsible for writing recorded data to a JSON file.
///
/// The `Writer` class retrieves file path details from environment variables and writes JSON data
/// to the appropriate location. It ensures that the target directory exists before writing.
class Writer: WriterInterface {

  /// The `ProcessInfo` instance used to retrieve environment variables.
  private let processInfo: ProcessInfo
  /// The `FileManager` instance used to manage file operations.
  private let fileManager: FileManager

  /// Initializes a new `Writer` instance.
  ///
  /// - Parameters:
  ///   - processInfo: The `ProcessInfo` instance used to access environment variables. Defaults to `.processInfo`.
  ///   - fileManager: The `FileManager` instance used to handle file system operations. Defaults to `.default`.
  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  /// Writes an array of recorded data to a JSON file.
  ///
  /// - Parameter recordings: A collection of dictionaries representing recorded network interactions.
  /// - Throws:
  ///   - `WriterError.filePathNotFound` if the environment variables for file path or filename are missing.
  ///   - `WriterError.couldNotSerializeJSON` if the JSON serialization fails.
  ///
  /// This method:
  /// 1. Retrieves the target file path and filename from the environment variables.
  /// 2. Serializes the provided recordings into JSON format.
  /// 3. Ensures the target directory exists before writing the file.
  /// 4. Saves the JSON data as a `.json` file at the specified location.
  func write(recordings: [[String: Any]]) throws {
    // Ensure the file path and filename exist in the environment variables.
    guard let path, let file else { throw WriterError.filePathNotFound }

    // Attempt to serialize the recordings into JSON data.
    guard let jsonData = try? JSONSerialization.data(withJSONObject: recordings) else {
      throw WriterError.couldNotSerializeJSON
    }

    // Construct the file URL and ensure the directory exists.
    var url = URL(fileURLWithPath: path, isDirectory: true)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

    // Append the filename and ensure it has a `.json` extension.
    url.appendPathComponent(file)
    url.deletePathExtension()
    url.appendPathExtension("json")

    // Write the serialized JSON data to the file.
    try jsonData.write(to: url)
  }
}

// MARK: - Private Extensions

private extension Writer {

  /// Retrieves the file path for storing recorded data.
  ///
  /// - Returns: The directory path specified in the `Decoy.Constants.mockDirectory` environment variable.
  var path: String? {
    processInfo.environment[Decoy.Constants.mockDirectory]
  }

  /// Retrieves the filename for the recorded data.
  ///
  /// - Returns: The filename specified in the `Decoy.Constants.mockFilename` environment variable.
  var file: String? {
    processInfo.environment[Decoy.Constants.mockFilename]
  }
}
