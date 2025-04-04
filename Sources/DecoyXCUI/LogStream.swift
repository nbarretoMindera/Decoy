import Foundation
import XCTest

/// A utility that streams log messages from the Decoy shared log file (`/tmp/decoy_live.log`)
/// and displays them in real-time as `XCTActivity` entries during UI test execution.
///
/// This class is intended for use in `XCTestCase` targets. It monitors the shared log file for changes
/// and creates an activity log for each complete log message (each line terminated by a newline character)
/// written by the application.
class LogStream {
  /// The URL of the shared log file.
  private let fileURL = URL(fileURLWithPath: "/tmp/decoy_live.log")

  /// The file handle used to read data from the log file.
  private var fileHandle: FileHandle?

  /// A dispatch source monitoring file system events (specifically, write events) on the log file.
  private var source: DispatchSourceFileSystemObject?

  /// A buffer that accumulates partial data until a complete line is received.
  private var buffer = Data()

  /// Initializes a new `LogStream` instance and begins streaming log messages.
  ///
  /// This initializer creates the log file if it does not exist, then sets up a file handle and
  /// a dispatch source that listens for write events. Each complete line detected is converted into
  /// an `XCTActivity` entry for real-time feedback in your test logs.
  ///
  /// - Parameter testCase: The `XCTestCase` instance that will own the log output.
  ///   This parameter allows the log entries to be associated with a specific test context.
  public init(testCase: XCTestCase) {
    // Ensure the log file exists.
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    // Attempt to create a file handle for reading.
    guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
    fileHandle = handle

    // Create a dispatch source to monitor the file for write events.
    let descriptor = handle.fileDescriptor
    source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)

    // Set up the event handler for new data.
    source?.setEventHandler { [weak self] in
      guard let self = self else { return }

      // Read available data from the file.
      let newData = self.fileHandle?.availableData ?? Data()
      guard !newData.isEmpty else { return }

      // Append new data to the buffer.
      self.buffer.append(newData)

      // Process each complete line (terminated by a newline character, 0x0A).
      while let newlineRange = self.buffer.range(of: Data([0x0A])) {
        // Extract the data for the line up to the newline.
        let lineData = self.buffer.subdata(in: 0..<newlineRange.lowerBound)
        // Remove the processed line (including the newline) from the buffer.
        self.buffer.removeSubrange(0...newlineRange.lowerBound)

        // Convert the line data to a string and trim whitespace/newline characters.
        if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !line.isEmpty {
          // Create an XCTActivity entry for the log line.
          XCTContext.runActivity(named: line) { _ in }
        }
      }
    }

    // Set up a cancel handler to clean up the file handle and dispatch source.
    source?.setCancelHandler { [weak self] in
      try? self?.fileHandle?.close()
      self?.fileHandle = nil
      self?.source = nil
    }

    // Start monitoring.
    source?.resume()
  }

  /// Stops listening for log entries and removes the shared log file from disk.
  ///
  /// Call this method from your test's `tearDown()` to ensure cleanup after test execution.
  /// This cancels the dispatch source and attempts to remove the log file, so that subsequent tests
  /// start with a fresh log.
  public func tearDown() {
    source?.cancel()
    try? FileManager.default.removeItem(at: fileURL)
  }

  deinit {
    // Ensure that the dispatch source is cancelled on deallocation.
    source?.cancel()
  }
}
