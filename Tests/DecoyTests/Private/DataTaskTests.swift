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

  func test_resume_shouldRecordRealResponse_inRecordMode() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: URL(string: "http://record-response.com")!)

    let DecoyTask = DataTask(mocking: task, mode: .record) { _, _, _ in }
    DecoyTask.resume(processInfo: mockedProcessInfo)

    XCTAssert(task.didCallResume, "Expected resume() to be called in record mode")
  }

  func test_resume_shouldReturnError_inForceOfflineMode_whenNoMockAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let url = URL(string: "http://no-mock.com")!
    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: url)

    var receivedError: Error?
    let DecoyTask = DataTask(mocking: task, mode: .forceOffline) { _, _, error in
      receivedError = error
    }
    DecoyTask.resume(processInfo: mockedProcessInfo)

    XCTAssertNotNil(receivedError, "Expected an error when no mock is available in forceOffline mode")
    XCTAssertFalse(task.didCallResume, "Expected task not to resume in forceOffline mode with no mock")
  }

  func test_resume_shouldReturnMockedResponse_inForceOfflineMode_whenAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let url = URL(string: "http://mocked-response.com")!
    guard let data = try? JSONSerialization.data(withJSONObject: ["key": "value"]) else { return XCTFail(#function) }
    let response = Stub.Response(data: data, urlResponse: nil, error: nil)
    Decoy.queue.queue(Stub: Stub(url: url, response: response))

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: url)

    var receivedData: Data?
    DataTask(mocking: task, mode: .forceOffline) { data, _, _ in
      receivedData = data
    }.resume(processInfo: mockedProcessInfo)

    XCTAssertNotNil(receivedData, "Expected a mocked response in forceOffline mode")
    XCTAssertFalse(task.didCallResume, "Expected task not to resume when a mock response is available")
  }

  func test_resume_shouldUseMockedResponse_inLiveIfUnmockedMode_whenAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let url = URL(string: "http://mocked-live.com")!
    guard let data = try? JSONSerialization.data(withJSONObject: ["mock": "yes"]) else { return XCTFail(#function) }
    let response = Stub.Response(data: data, urlResponse: nil, error: nil)
    Decoy.queue.queue(Stub: Stub(url: url, response: response))

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: url)

    var receivedData: Data?
    DataTask(mocking: task, mode: .liveIfUnmocked) { data, _, _ in
      receivedData = data
    }.resume(processInfo: mockedProcessInfo)

    XCTAssertNotNil(receivedData, "Expected a mocked response when available")
    XCTAssertFalse(task.didCallResume, "Expected task not to resume when a mock is available")
  }

  func test_resume_shouldDeferToSuperclass_inLiveIfUnmockedMode_whenNoMockAvailable() {
    mockedProcessInfo.mockedIsRunningXCUI = true

    let task = MockURLSessionDataTask()
    task.mockedCurrentRequest = URLRequest(url: URL(string: "http://real-call.com")!)

    let DecoyTask = DataTask(mocking: task, mode: .liveIfUnmocked) { _, _, _ in }
    DecoyTask.resume(processInfo: mockedProcessInfo)

    XCTAssert(task.didCallResume, "Expected resume() to be called when no mock is available")
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
