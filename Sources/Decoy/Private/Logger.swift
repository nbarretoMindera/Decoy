import Foundation
import OSLog

/// A simple logging utility for the Decoy framework.
///
/// This utility wraps Apple's OSLog `Logger` and provides a convenience method for logging messages
/// with a custom prefix. It can be used throughout the Decoy framework to log informational messages.
struct Log {
  /// The underlying OSLog `Logger` instance used for logging.
  private let logger: Logger

  /// Initializes a new instance of `Log`.
  ///
  /// - Parameter logger: An optional `Logger` instance. If none is provided, a default `Logger` is used.
  init(logger: Logger = Logger()) {
    self.logger = logger
  }

  /// Logs an informational message.
  ///
  /// - Parameter message: The message to be logged.
  /// The message is logged at the `.info` level.
  func log(_ message: String) {
    logger.info("🦆 Decoy: \(message)")
  }
}
