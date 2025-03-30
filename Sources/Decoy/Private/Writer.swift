import Foundation

protocol WriterInterface {
  func write(recordings: [[String: Any]]) throws
}

enum WriterError: Error {
  case filePathNotFound
  case couldNotSerializeJSON
}

class Writer: WriterInterface {
  private let processInfo: ProcessInfo
  private let fileManager: FileManager
  // A serial dispatch queue to prevent concurrent file accesses.
  private let syncQueue = DispatchQueue(label: "com.yourapp.writerQueue")

  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  func write(recordings newRecordings: [[String: Any]]) throws {
    try syncQueue.sync {
      // Ensure we have both the path and file name from the environment.
      guard let path, let file else { throw WriterError.filePathNotFound }

      // Construct the target file URL.
      var url = URL(fileURLWithPath: path, isDirectory: true)
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
      url.appendPathComponent(file)
      url.deletePathExtension()
      url.appendPathExtension("json")

      // Read existing recordings from disk, if any.
      var existingRecordings = [[String: Any]]()
      if fileManager.fileExists(atPath: url.path),
         let data = try? Data(contentsOf: url),
         let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        existingRecordings = jsonArray
      }

      // Merge the existing recordings with the new ones.
      // You can adjust the merge logic as needed—for example, you might choose to deduplicate entries.
      let mergedRecordings = existingRecordings + newRecordings

      // Serialize the merged array to JSON data.
      guard let jsonData = try? JSONSerialization.data(withJSONObject: mergedRecordings) else {
        throw WriterError.couldNotSerializeJSON
      }

      // Write the merged JSON data to disk.
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
