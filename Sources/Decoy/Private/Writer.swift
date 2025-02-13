//
//  File.swift
//  
//
//  Created by Charman, Luke on 22/03/2023.
//

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

  init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
    self.processInfo = processInfo
    self.fileManager = fileManager
  }

  func write(recordings: [[String: Any]]) throws {
    guard let path, let file else { throw WriterError.filePathNotFound }
    guard let data = try? JSONSerialization.data(withJSONObject: recordings, options: .prettyPrinted) else {
      throw WriterError.couldNotSerializeJSON
    }

    var url = URL(safePath: path)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

    url.safeAppend(path: file)
    try data.write(to: url)
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
