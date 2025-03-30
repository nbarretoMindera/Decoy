import Foundation
import OSLog

struct Log {
  private let logger: Logger

  init(logger: Logger = Logger()) {
    self.logger = logger
  }

  func log(_ message: String) {
    NSLog("This is an NSLog message from UITests")
    logger.info("🦆 Decoy: \(message)")
  }
}
