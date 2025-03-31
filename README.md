<div align="center">
  <img src="https://github.com/user-attachments/assets/47cf7f03-053b-4762-bb67-2831944cfc0d" width="350" alt="Decoy Logo">
</div>

# Decoy

## ❓ What is Decoy?

Decoy is a Swift package that intercepts network requests made via URLSession or GraphQL via Apollo and returns pre-configured mock responses (or records live responses) without the need for an external HTTP server. Designed primarily for XCUI tests, Decoy lets you simulate network responses entirely within Xcode, so your UI tests run quickly and reliably.

Using Decoy, you can:
* **Record live responses**: Automatically capture real API responses and store them as mocks.
* **Queue mocked responses**: Specify and queue JSON mocks for particular endpoint URLs.
* **Replay mocks in sequence**: Return queued mocks in a controlled flow during testing.
* **Keep production code untouched**: Your app uses URLSession / Apollo as normal, and Decoy intercepts calls under the hood.

## 🧱 How do I implement it?

The `Decoy` package contains three targets: `Decoy`, `DecoyApollo`, and `DecoyXCUI`. `Decoy` must be added as a dependency of your app target. `DecoyApollo` should also be added to your app target if it uses Apollo and you'd like to mock GraphQL. `DecoyXCUI` should be added to your UI testing target. These packages are only a few kilobytes in size and will have no major impact on the size of your release binary in the App Store. Decoy works best when your app uses a shared instance of `URLSession` or a single `Apollo` instance, as in this case, you only need `import Decoy` once.

For a setup without GraphQL, to get up and running:

### In the project:
* Add the Decoy package as a depedency.
* Choose the `Decoy` target as a dependency for your **app** target.
* Choose the `DecoyXCUI` target as a dependency for your **UI test** target.

### In the app:
* Set up Decoy on launch:
  ```
  Decoy.setUp()
  ```
* When you use `URLSession` in your app, use `Decoy.urlSession` instead:
  ```
  FooAPIClient(urlSession: Decoy.urlSession)
  ```
* Or, if you use a custom `URLConfiguration`, add `DecoyURLProtocol` to its list of `protocolClasses`:
  ```
  configuration.protocolClasses = [DecoyURLProtocol.self] + (configuration.protocolClasses ?? [])
  ```

### In the UI test target:
* In your UI test target, have the test classes inherit from `DecoyTestCase`.
* Call the custom `setUp()` method, like so, passing in the test mode you'd like to use.
  ```
  override func setUp() {
    super.setUp(mode: .record) // or .liveIfUnmocked, .forceOffline
  }
  ```
* This will launch your app with the required environment variables to use Decoy.

For a setup using GraphQL:

### In the project:
* Add the Decoy package as a depedency.
* Choose the `Decoy` target as a dependency for your **app** target.
* Choose the `DecoyApollo` target as a dependency for your **app** target.
* Choose the `DecoyXCUI` target as a dependency for your **UI test** target.

### In the app:
* Set up Decoy on launch:
  ```
  Decoy.setUp()
  ```
* When you use `Apollo` in your app, add a `DecoyInterceptor` in front of any others.
  ```
  override public func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
    let interceptorsToAdd: [ApolloInterceptor] = [
      DecoyInterceptor(),
      // Any of your other interceptors...
    ]
  ```

### In the UI test target:
* In your UI test target, have the test classes inherit from `DecoyTestCase`.
* Call the custom `setUp()` method, like so, passing in the test mode you'd like to use.
  ```
  override func setUp() {
    super.setUp(mode: .record) // or .liveIfUnmocked, .forceOffline
  }
  ```
* This will launch your app with the required environment variables to use Decoy.


## 🔴 Can I record with it?

Yes! One of Decoy' handier features is the ability to record real responses provided by your APIs, and then play them back when running the tests. You can think of this similarly to how recording works in popular snapshot testing libraries, where you'll record a "known good" state of your API, then not hit the real network when running your tests, allowing your UI tests to be exactly that, rather than full integration tests.

### How to record:
* First, write your UI test using your real API. Ensure that it's reliable and passes.
* Once you're happy, ask Decoy to record it by changing your `setUp()` method, like so:
  ```
  override func setUp() {
    super.setUp(mode: .record)
  }
  ```
* Now, run the test again.
* As the test progresses, each call to the network through your mocked `URLSession` will now be captured.
* When the test completes, these are written to a `__Decoys__` directory in your UI tests target.
* They will be automatically titled with the name of the individual test case you were running, plus `.json`.

### How to play back:
* First, switch recording mode back off:
  ```
  override func setUp() {
    super.setUp(mode: .liveIfUnmocked)
  }
  ```
* Now, re-run your tests.
* Decoy will detect that a mock exists with the given test name, and will pass it on to your app.

## 🔨 How does it work?

For `URLSession`, Decoy leverages a custom URLProtocol (`DecoyURLProtocol`) to intercept all network requests made by a URLSession. Or, when mocking Apollo, Decoy provides a custom Interceptor which you can add to retrieve and serve the mocks. The protocol and interceptor:
* Checks for a queued mock in Decoy’s internal queue:
  * If a mock exists, it returns the mock (and records it if recording is enabled).
* Performs a live network request if no mock is found and the mode is .liveIfUnmocked or .record:
  * In record mode, it records the live response.
* Throws an error in .forceOffline mode if no mock is available.

Decoy also provides a `setUp()` function that loads mocks from disk (using environment-specified directory and filenames) and queues them, and a `urlSession` computed property that returns a `URLSession` configured to use the `DecoyURLProtocol`.

## 👩‍💻 Can I try it for myself?

There's a `DecoyExample` in this repository. You can build it and take a look, it's super simple. It uses a couple of free public APIs as examples and its UI test target shows how to mock single or multiple calls to single or multiple endpoints with Decoy.

## 💡 What are your future plans for Decoy?

It's still early days, and I'm excited to see how we can continue to grow Decoy into an even more useful UI test mocking library. It's a specific use case that I don't really want to deviate from too much, I'm thinking of these tests as snapshots with a flow, and separate from integration testing (which is still crucially important).

Some specific things that still need doing / some ideas for the future:
* Enhancing error representation in JSON mocks.
* Verify recorded mocks are still up to date versus responses delivered from the backend they are mocking (avoid mock drift).
