# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`RxTcpSwift` is a small Swift library that wraps Foundation `InputStream`/`OutputStream` TCP sockets in RxSwift 6. It targets iOS 13+ and macOS 10.15+. It ships two ways from the same `Sources/RxTcpSwift/*.swift`:
- **Swift Package Manager**: `Package.swift`, tools 5.7, product `RxTcpSwift`.
- **CocoaPods**: `RxTcpSwift.podspec` (depends on `RxSwift`/`RxRelay` `~> 6.5.0`).

Consumers resolve a git tag. `AlgoHealth_iOS` pins `0.0.3` through SPM, via `AlgorigoPlatformSwift`. The repo doesn't record whether the podspec is ever pushed to a spec repo.

## Commands

```bash
swift build                                   # library only (iOS/macOS platforms declared)
pod lib lint RxTcpSwift.podspec

# Sample app (CocoaPods, consumes the pod via :path => '../')
cd RxTcpSwiftApp && pod install
xcodebuild -workspace RxTcpSwiftApp/RxTcpSwiftApp.xcworkspace -scheme RxTcpSwiftApp \
  -destination 'generic/platform=iOS Simulator' build
```

- **No working automated tests.** `Tests/RxTcpSwiftTests` asserts on `RxTcpSwift().text`, which doesn't exist, so `swift test` fails to compile until that test is fixed. The sample app's test targets contain only Xcode templates.
- **No shared schemes are committed.** Xcode auto-creates them, so check names with `xcodebuild -list` before scripting.
- **The sample app workspace isn't tracked.** `.gitignore` excludes `*.xcworkspace`, `Pods`, and `Podfile.lock`, so run `pod install` before opening it.
- **The sample app is a multiplatform SwiftUI target** (`SDKROOT = auto`; iOS 14.7 / macOS 10.15). It hardcodes LAN test-server addresses and ports in `ContentView.swift` and `TestCommunication*.swift`, so real verification needs a TCP server on the network.

## Architecture

Three public types. The two `*TcpSocketCommunication` classes are `open` base classes meant to be subclassed per protocol.

**`RxTcp`** is the raw socket.
- `connect(output: Observable<Data>) -> Observable<RxTcp>` opens both streams with `Stream.getStreamsToHost`. It emits `self` once both report `.openCompleted`.
- Every `Data` from `output` is written to the socket, observed on a background queue.
- Completing `output` completes the connection. Disposing the subscription closes both streams and resets the state to `.disconnected`.
- `getObservable()` returns received bytes, read in 1024-byte chunks. It is only valid after `connect` has emitted; before that it errors with `notConnected`.
- Calling `connect` again while it is connecting or connected errors with `alreadyConnected`.

**`ReceiveTcpSocketCommunication`** handles server-push streams.
- `connect()` returns a `Completable`.
- Incoming bytes accumulate in a buffer. The buffer is passed repeatedly to the subclass's `verifyReceivedData(data:) -> (returnData, rest)` until it returns `nil`. The default implementation calls `fatalError`.
- **Every frame returned is pushed into `outputSubject`, which is the same subject fed to `RxTcp` as `output`. So each verified frame is written back to the server.** Frames are not exposed any other way.

**`SendingTcpSocketCommunication`** handles request/response.
- `connect()` emits `self`. `sendData(data:receivedDataVerifier:) -> Single<Data>` queues a request, and only one request is in flight at a time.
- Received bytes accumulate until the in-flight request's verifier returns `true`. That request then receives the whole accumulated buffer, and the buffer is cleared.
- Bytes that arrive while no request is in flight stay in the buffer and get prepended to the next response.
- The next queued request is sent when the previous `Single` is disposed.
- `finalizeConnection()` completes the output, which closes the socket.

## Gotchas

- Streams are scheduled on `RunLoop.main`, and `RxTcp.connect` delivers on `MainScheduler`. Anything driving a connection, including a future unit test, needs the main run loop running.
- `connect(timeout:printLog:)` on both communication classes accepts these parameters but ignores them. `TIMEOUT_MILLIS` is unused, so there is no connect timeout unless the caller adds one.
- `RxTcpSwift.version` in `Sources/RxTcpSwift/RxTcpSwift.swift` is stale (`v0.0.1`). The podspec `spec.version` is the real version.
- `README.md` is a stub.

## Releasing

Release branches are named by the bare version (`0.0.3`) and merged into `master` and `develop`. The version commit is `version name X.Y.Z` and bumps `spec.version` in `RxTcpSwift.podspec`. The tag is the bare version with no `v` prefix, and it must match `spec.version` because the podspec `:tag` is `#{spec.version}`.
