import Foundation

class AsyncOperation: Operation, @unchecked Sendable {

    private let stateLock = NSLock()

    private var _isExecuting = false
    private var _isFinished = false

    override var isAsynchronous: Bool {
        true
    }

    override private(set) var isExecuting: Bool {
        get {
            stateLock.withLock {
                _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")

            stateLock.withLock {
                _isExecuting = newValue
            }

            didChangeValue(forKey: "isExecuting")
        }
    }

    override private(set) var isFinished: Bool {
        get {
            stateLock.withLock {
                _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")

            stateLock.withLock {
                _isFinished = newValue
            }

            didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        guard !isCancelled else {
            finish()
            return
        }

        isExecuting = true
        main()
    }

    func finish() {
        guard !isFinished else {
            return
        }

        isExecuting = false
        isFinished = true
    }
}
