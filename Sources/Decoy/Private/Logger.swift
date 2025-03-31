import Foundation
import OSLog

/// A protocol that defines a simple logging interface adopted in `DecoyXCUI`.
public protocol LoggerProtocol {
  func log(_ message: String)
}

public struct Logger: LoggerProtocol {
  private let logPath = "/tmp/decoy_live.log"

  public init() {}

  public func log(_ message: String) {
    let line = message + "\n"
    guard let data = line.data(using: .utf8) else { return }

    if FileManager.default.fileExists(atPath: logPath) {
      if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.close()
      }
    } else {
      try? data.write(to: URL(fileURLWithPath: logPath))
    }
  }
}
