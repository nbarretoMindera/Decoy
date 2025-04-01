import Foundation
import XCTest

/// A utility that streams log messages from the Decoy shared log file (`/tmp/decoy_live.log`)
/// and displays them in real-time as `XCTActivity` entries during UI test execution.
///
/// This class is designed to be used in `XCTestCase` test targets.
/// It monitors the shared log file for changes and creates activity logs for each
/// complete log message line written by the application.
public final class DecoyLogStream {
  /// The path to the shared Decoy log file.
  private let fileURL = URL(fileURLWithPath: "/tmp/decoy_live.log")
  private var fileHandle: FileHandle?
  private var source: DispatchSourceFileSystemObject?
  private var buffer = Data()

  /// Starts listening for log entries written to `/tmp/decoy_live.log`.
  /// - Parameter testCase: The `XCTestCase` instance that will own the log output.
  public init(testCase: XCTestCase) {
    // Ensure log file exists
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
    fileHandle = handle

    let descriptor = handle.fileDescriptor
    source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)

    source?.setEventHandler { [weak self] in
      guard let self = self else { return }
      let newData = self.fileHandle?.availableData ?? Data()
      guard !newData.isEmpty else { return }

      self.buffer.append(newData)

      // Process each complete line (terminated by newline character)
      while let newlineRange = self.buffer.range(of: Data([0x0A])) {
        let lineData = self.buffer.subdata(in: 0..<newlineRange.lowerBound)
        self.buffer.removeSubrange(0...newlineRange.lowerBound)

        if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
          XCTContext.runActivity(named: line) { _ in }
        }
      }
    }

    source?.setCancelHandler { [weak self] in
      try? self?.fileHandle?.close()
      self?.fileHandle = nil
      self?.source = nil
    }

    source?.resume()
  }

  /// Stops listening and removes the shared log file from disk.
  /// Call this from `tearDown()` to clean up after the test.
  public func tearDown() {
    source?.cancel()
    try? FileManager.default.removeItem(at: fileURL)
  }

  deinit {
    source?.cancel()
  }
}
