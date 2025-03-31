import Foundation

/// A protocol defining a writer that stores recorded data.
protocol WriterInterface {
  /// Appends a single recording to the file.
  func append(recording: [String: Any]) throws
}

/// An enumeration defining possible errors encountered during the writing process.
enum WriterError: Error {
  /// Indicates that the file path or filename was not found in the environment variables.
  case filePathNotFound
  /// Indicates that JSON serialization of the provided recordings failed.
  case couldNotSerializeJSON
}

/// A class responsible for writing recorded data to a JSON file.
/// This implementation uses a shared global serial queue so that multiple calls from
/// different Recorder instances are ordered correctly.
class Writer: WriterInterface {
  private let processInfo: ProcessInfo
  private let fileManager: FileManager

  // A shared global serial queue for all writes.
  private static let globalQueue = DispatchQueue(label: "com.yourapp.globalWriterQueue")

  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  func append(recording: [String: Any]) throws {
    try Writer.globalQueue.sync {
      // Retrieve the file path and filename from environment variables.
      guard let path = self.path, let file = self.file else {
        throw WriterError.filePathNotFound
      }

      // Construct the file URL.
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

      existingRecordings.append(recording)

      // Serialize the merged array to JSON.
      guard let jsonData = try? JSONSerialization.data(withJSONObject: existingRecordings) else {
        throw WriterError.couldNotSerializeJSON
      }

      // Write the JSON data to disk.
      try jsonData.write(to: url)
    }
  }
}

private extension Writer {
  var path: String? {
    processInfo.environment[Decoy.Constants.mockDirectory]
  }

  var file: String? {
    processInfo.environment[Decoy.Constants.mockFilename]
  }
}
