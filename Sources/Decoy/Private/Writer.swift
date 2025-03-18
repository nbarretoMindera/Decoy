import Compression
import Foundation

protocol WriterInterface {
  func write(recordings: [[String: Any]]) throws
}

enum WriterError: Error {
  case filePathNotFound
  case couldNotSerializeJSON
  case compressionFailed
}

class Writer: WriterInterface {
  private let processInfo: ProcessInfo
  private let fileManager: FileManager

  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  func write(recordings: [[String: Any]]) throws {
    guard let path, let file else { throw WriterError.filePathNotFound }
    guard let jsonData = try? JSONSerialization.data(withJSONObject: recordings) else {
      throw WriterError.couldNotSerializeJSON
    }

    var url = URL(fileURLWithPath: path, isDirectory: true)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

    url.appendPathComponent(file)
    url.deletePathExtension()
    url.appendPathExtension("json")

    try jsonData.write(to: url)
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
