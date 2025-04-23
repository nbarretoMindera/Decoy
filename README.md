<div align="center">
  <img src="https://github.com/user-attachments/assets/47cf7f03-053b-4762-bb67-2831944cfc0d" width="350" alt="Decoy Logo">
</div>

# Decoy

## ❓ What is Decoy?

Decoy is a Swift package that intercepts network requests made via URLSession or GraphQL via Apollo and returns pre-configured mock responses (or records live responses) without the need for any external HTTP server. Designed for XCUI tests, Decoy lets you simulate network responses entirely within Xcode, so your UI tests run quickly and reliably.

Using Decoy, you can:
* **Record live responses**: Automatically capture real API responses and store them as mocks.
* **Queue mocked responses**: Specify and queue JSON mocks for particular endpoint URLs or GQL queries.
* **Replay mocks in sequence**: Return queued mocks in a controlled flow during testing.
* **Keep production code untouched**: Your app uses URLSession / Apollo as normal, and Decoy intercepts calls under the hood.

## 🧱 How do I implement it?

The `Decoy` package contains three targets: `Decoy`, `DecoyApollo`, and `DecoyXCUI`.
* `Decoy` must be added as a dependency of your app target.
* `DecoyApollo` should also be added to your app target if it uses Apollo and you'd like to mock GraphQL.
* `DecoyXCUI` should be added to your UI testing target.

These packages are only a few kilobytes in size and will have no major impact on the size of your release binary in the App Store. Decoy works best when your app uses a shared instance of `URLSession` or a single `Apollo` instance, as in this case, you only need `import Decoy` once and call a one-line setUp method.

To get up and running:

### In the project:
* Add the Decoy package as a depedency.
* Choose the `Decoy` target as a dependency for your **app** target.
* If using GraphQL, choose the `DecoyApollo` target as a dependency for your **app** target.
* Choose the `DecoyXCUI` target as a dependency for your **UI test** target.

### In the app:
* Set up Decoy on launch:
  ```
  Decoy.setUp()
  ```
* When you use `URLSession` in your app, use `Decoy.urlSession` instead:
  ```
  FooAPIClient(urlSession: .decoy)
  ```
* Or, if you use a custom `URLConfiguration`, add a Decoy to it:
  ```
  configuration.insertDecoy()
  ```
* If you're using Apollo, add a `DecoyInterceptor` to your interceptor chain at the top:
  ```
  interceptors.insert(DecoyInterceptor(), at: 0)
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
* As the test progresses, each call to the network through your mocked `URLSession` or interceptor will now be captured.
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
* Decoy will detect that a mock exists with the given test name, and will pass it on to your app when requested.

## 🔨 How does it work?

For `URLSession`, Decoy leverages a custom URLProtocol (`DecoyURLProtocol`) to intercept all network requests made by a URLSession. Or, when mocking Apollo, Decoy provides a custom Interceptor which you can add to retrieve and serve the mocks. The protocol and interceptor:
* Check for a queued mock in Decoy’s internal queue:
  * If a mock exists, return the mock (and record it if recording is enabled).
* Perform a live network request if no mock is found and the mode is .liveIfUnmocked or .record:
  * In record mode, record the live response.
* Throw an error in .forceOffline mode if no mock is available for purely offline testing.

Decoy also provides a `setUp()` function that loads mocks from disk (using environment-specified directory and filenames) and queues them, and extends `URLSession` with `URLSession.decoy`, which returns a `URLSession` pre-configured to use the `DecoyURLProtocol`.

## 👩‍💻 Can I try it for myself?

There's a `DecoyExample` in this repository. You can build it and take a look, it's super simple. It uses a couple of free public APIs as examples and its UI test target shows how to mock single or multiple calls to single or multiple endpoints with Decoy.

## 🌊 How do I know that my mock schemas aren't out of date with my real backend?
* This is a nice incidental benefit of Decoy, and while it's reactive rather than proactive, it means that your tests fail if your model objects change.
* Your mocks represent a moment in time at which they were recorded, and your UI test that uses them is linked to that moment.
* If your backend teams change a schema and your mocks no longer align to it, your app will break, and you'll fix it. This is the "reactive" part.
* But what this means is that as soon as you've changed your app, your UI tests will fail because the mocks are still set to the old schema.
* That way, you'll know that you're dealing with an out-of-date mock and you can go re-record and update your test.
* We'll be actively adding ways to proactively check the validity of mocks against live endpoints soon. Which leads to the question...

## 💡 What are your future plans for Decoy?

It's still early days, and I'm excited to see how we can continue to grow Decoy into an even more useful UI test mocking library.

Some specific things that still need doing / some ideas for the future:
* Enhancing error representation in JSON mocks.
* Proactively verify that recorded mocks are still up to date versus responses delivered from the backend they are mocking (avoid mock drift).
* Avoid app launch boilerplate in mocks by recording a separate set of "base mocks" which are checked if not found amongst your specific test's mocks. 
