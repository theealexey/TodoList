import Testing
@testable import TodoList

@MainActor
struct AppContainerTests {

    @Test
    func concurrentPrepareSharesSingleInFlightPreparation() async throws {
        let preparation = SuspendedPreparation()

        let container = AppContainer(
            coreDataStack: CoreDataStack(inMemory: true),
            coreDataPreparation: {
                await preparation.run()
            }
        )

        let firstTask = Task { @MainActor in
            try await container.prepare()
        }

        await preparation.waitUntilStarted()

        let secondStartSignal = StartSignal()

        let secondTask = Task { @MainActor in
            secondStartSignal.markStarted()
            try await container.prepare()
        }

        await secondStartSignal.waitUntilStarted()

        let inFlightCallCount = await preparation.callCount

        #expect(inFlightCallCount == 1)

        await preparation.finishAll()

        try await firstTask.value
        try await secondTask.value

        let finalCallCount = await preparation.callCount

        #expect(finalCallCount == 1)
    }

    @Test
    func prepareRetriesAfterFailure() async throws {
        let preparation = FailingOncePreparation()

        let container = AppContainer(
            coreDataStack: CoreDataStack(inMemory: true),
            coreDataPreparation: {
                try await preparation.run()
            }
        )

        do {
            try await container.prepare()

            Issue.record(
                "Expected the first preparation to fail"
            )
        } catch PreparationFailure.expected {
            // Expected failure.
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        try await container.prepare()

        let callCount = await preparation.callCount

        #expect(callCount == 2)
    }
}

@MainActor
private final class StartSignal {

    private var isStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        isStarted = true
        continuation?.resume()
        continuation = nil
    }

    func waitUntilStarted() async {
        guard !isStarted else {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

private actor SuspendedPreparation {

    private(set) var callCount = 0

    private var continuations:
        [CheckedContinuation<Void, Never>] = []

    private var startContinuations:
        [CheckedContinuation<Void, Never>] = []

    func run() async {
        callCount += 1

        let pendingStartContinuations = startContinuations
        startContinuations.removeAll()

        pendingStartContinuations.forEach {
            $0.resume()
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilStarted() async {
        guard callCount == 0 else {
            return
        }

        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func finishAll() {
        let pendingContinuations = continuations
        continuations.removeAll()

        pendingContinuations.forEach {
            $0.resume()
        }
    }
}

private actor FailingOncePreparation {

    private(set) var callCount = 0

    func run() async throws {
        callCount += 1

        if callCount == 1 {
            throw PreparationFailure.expected
        }
    }
}

private enum PreparationFailure: Error {
    case expected
}
