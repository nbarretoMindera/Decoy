import Foundation
import XCTest
@testable import Decoy

final class DataTaskTests: XCTestCase {
  var mockedProcessInfo: MockProcessInfo!

  override func setUp() {
    super.setUp()
    mockedProcessInfo = MockProcessInfo()
  }

  override func tearDown() {
    mockedProcessInfo = nil
    super.tearDown()
  }

  func test_init_shouldStoreTask() {
    let task = URLSessionDataTask()
    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    XCTAssertIdentical(task, DecoyTask.task)
  }

  func test_overriddenResume_shouldCallInternalResume() {
    let task = MockURLSessionDataTask()
    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    DecoyTask.resume()
    XCTAssert(task.didCallResume)
  }

  func test_resume_shouldDeferToSuperclass_whenTaskHasNoURL() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let task = MockURLSessionDataTask()
    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    DecoyTask.resume(processInfo: mockedProcessInfo)
    XCTAssert(task.didCallResume)
  }

  func test_resume_shouldDeferToSuperclass_whenNotRunningXCUI() {
    mockedProcessInfo.mockedIsRunningXCUI = false

    let task = MockURLSessionDataTask()
    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    DecoyTask.resume(processInfo: mockedProcessInfo)
    XCTAssert(task.didCallResume)
  }

  func test_resume_shouldDeferToSuperclass_whenNoQueuedResponseIsAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: URL(string: "http://no-mocks.for.me")!)

    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    DecoyTask.resume(processInfo: mockedProcessInfo)
    XCTAssert(task.didCallResume)
  }

  func test_resume_shouldReturnNextMockedResponse_whenAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let url = URL(string: "A")!
    guard let data = try? JSONSerialization.data(withJSONObject: ["A": "B"]) else { return XCTFail(#function) }
    let response = Stub.Response(data: data, urlResponse: nil, error: nil)
    Decoy.queue.queue(Stub: Stub(url: URL(string: "A")!, response: response))

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: url)

    DataTask(mocking: task, mode: .liveIfUnmocked) { data, _, _ in
      guard let data = data else {
        return XCTFail(#function)
      }

      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return XCTFail(#function)
      }

      XCTAssertEqual(json["A"] as? String, "B")
    }.resume(processInfo: mockedProcessInfo)

    XCTAssertFalse(task.didCallResume)
  }
}

private class MockURLSessionDataTask: URLSessionDataTask {

  var didCallResume = false
  var mockedCurrentRequest: URLRequest?

  override func resume() {
    didCallResume = true
  }

  override var currentRequest: URLRequest? {
    mockedCurrentRequest
  }
}
