import Foundation
import XCTest

/// Streams Decoy logs from the shared log file in real time as XCTActivities.
public final class DecoyLogStream {
  private let fileURL = URL(fileURLWithPath: "/tmp/decoy_live.log")
  private var fileHandle: FileHandle?
  private var source: DispatchSourceFileSystemObject?

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
      let data = handle.availableData
      guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
      XCTContext.runActivity(named: "🦆 Decoy: \(text.trimmingCharacters(in: .newlines))") { _ in }
    }

    source?.setCancelHandler { [weak self] in
      try? self?.fileHandle?.close()
      self?.fileHandle = nil
      self?.source = nil
    }

    source?.resume()
  }

  public func tearDown() {
    source?.cancel()
    try? FileManager.default.removeItem(at: fileURL)
  }

  deinit {
    source?.cancel()
  }
}
