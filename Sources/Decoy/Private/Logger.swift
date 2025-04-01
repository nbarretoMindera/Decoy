import Foundation
import OSLog

/// A protocol defining a structured logging interface used by Decoy.
public protocol LoggerProtocol {
  /// Logs an informational message.
  func info(_ message: String)

  /// Logs a warning message.
  func warning(_ message: String)

  /// Logs an error message.
  func error(_ message: String)
}

/// A logger that writes messages to a shared log file in `/tmp`,
/// used for real-time streaming into UI tests.
public struct Logger: LoggerProtocol {
  private let logPath = "/tmp/decoy_live.log"

  /// Creates a new logger that writes to `/tmp/decoy_live.log`.
  public init() {}

  /// Logs an informational message.
  /// - Parameter message: The message to log.
  public func info(_ message: String) {
    write("🦆 Decoy Info: ", message)
  }

  /// Logs a warning message.
  /// - Parameter message: The warning message to log.
  public func warning(_ message: String) {
    write("⚠️ Decoy Warning: ", message)
  }

  /// Logs an error message.
  /// - Parameter message: The error message to log.
  public func error(_ message: String) {
    write("❌ Decoy Error: ", message)
  }

  /// Writes a message with a prefix tag to the shared log file.
  /// - Parameters:
  ///   - level: A short tag to prefix the log with (e.g. INFO, WARN).
  ///   - message: The actual message to log.
  private func write(_ level: String, _ message: String) {
    let line = "\(level) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    let url = URL(fileURLWithPath: logPath)

    if FileManager.default.fileExists(atPath: logPath) {
      if let handle = try? FileHandle(forWritingTo: url) {
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.close()
      }
    } else {
      try? data.write(to: url)
    }
  }
}
