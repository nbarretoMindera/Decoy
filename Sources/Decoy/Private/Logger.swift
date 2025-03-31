import Foundation
import OSLog

/// A protocol that defines a simple logging interface.
protocol LoggerProtocol {
  /// Logs an informational message.
  func info(_ message: String)
}

/// A production logger that wraps OSLog.Logger.
struct OSLogger: LoggerProtocol {
  private let logger: Logger

  /// Initializes with an OSLog.Logger.
  init(logger: Logger = Logger(subsystem: "com.lukecharman.decoy", category: "default")) {
    self.logger = logger
  }

  func info(_ message: String) {
    // The privacy parameter can be adjusted as needed.
    logger.info("\(message, privacy: .public)")
  }
}

/// A test logger that captures logged messages.
class TestLogger: LoggerProtocol {
  var messages: [String] = []

  func info(_ message: String) {
    messages.append(message)
  }
}

/// A simple logging utility for the Decoy framework.
///
/// This utility wraps a logger conforming to LoggerProtocol and provides a convenience method
/// for logging messages with a custom prefix.
struct Log {
  /// The underlying logger used for logging.
  private let logger: LoggerProtocol

  /// Initializes a new instance of `Log`.
  ///
  /// - Parameter logger: An optional logger conforming to LoggerProtocol.
  ///                     If none is provided, a default OSLogger is used.
  init(logger: LoggerProtocol = OSLogger()) {
    self.logger = logger
  }

  /// Logs an informational message with the "🦆 Decoy:" prefix.
  ///
  /// - Parameter message: The message to be logged.
  func log(_ message: String) {
    logger.info("🦆 Decoy: \(message)")
  }
}
