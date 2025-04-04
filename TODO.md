To do in Decoy's library itself:
- Get the GQL Integration test finished.
- Battle-test the GQL implementation a bit more.
- Ensure that the GQL implementation can do URL responses.
- Add better support for writing errors to disk.
- Ability to create a shared set of Decoys which are checked first to avoid repetition / app launch boilerplate / huge mocks.

For the Example app:
- Make a GraphQL Example with a proper Apollo schema for some public GQL API.

This has nothing to do with Decoy but is needed for MS3:
- We need a way to pass flags – copy what we did for Appium with launch args, be sure it works with both flagging libraries.
- Add some standard for UI testing – type-safe accessibility identifiers across packages, waits, timeouts, etc.

Future:
- Talk to Lisa / James about open-sourcing it.
