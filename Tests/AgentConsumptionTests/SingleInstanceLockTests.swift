import Foundation
import Testing

@testable import AgentConsumption

/// Only one copy of the app may create a menu bar item: a second one makes macOS mark the item as
/// removed for good. The lock is the operating system's, so two launches at the same instant cannot
/// both win, or both lose; and a lock that cannot be made at all is reported, not mistaken for another
/// copy running.
struct SingleInstanceLockTests {
    private func lock(_ outcome: SingleInstanceLock.Outcome) -> SingleInstanceLock? {
        if case let .acquired(lock) = outcome { return lock }
        return nil
    }

    @Test func theFirstLaunchTakesTheLockAndASecondIsToldAnotherCopyHasIt() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("app.lock")
        let first = try #require(lock(SingleInstanceLock.acquire(at: file)))
        guard case .heldElsewhere = SingleInstanceLock.acquire(at: file) else {
            Issue.record("a second acquisition must report contention")
            return
        }
        first.release()
    }

    @Test func releasingTheLockLetsTheNextLaunchTakeIt() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("app.lock")
        try #require(lock(SingleInstanceLock.acquire(at: file))).release()
        try #require(lock(SingleInstanceLock.acquire(at: file))).release()
    }

    @Test func differentAppsDoNotShareALock() throws {
        let sandbox = Sandbox()
        let one = try #require(lock(SingleInstanceLock.acquire(at: sandbox.directory.appendingPathComponent("a.lock"))))
        let other = try #require(
            lock(SingleInstanceLock.acquire(at: sandbox.directory.appendingPathComponent("b.lock"))))
        one.release()
        other.release()
    }

    @Test func manySimultaneousLaunchesProduceExactlyOneWinnerAndNoFailures() {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("race.lock")
        let winners = LockedBox<[SingleInstanceLock]>([])
        let failures = LockedBox(0)
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            switch SingleInstanceLock.acquire(at: file) {
            case let .acquired(lock): winners.value.append(lock)
            case .heldElsewhere: break
            case .failed: failures.value += 1
            }
        }
        #expect(winners.value.count == 1)
        #expect(failures.value == 0)
        winners.value.forEach { $0.release() }
    }

    @Test func aLockInAMissingFolderIsCreatedThere() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("nested/dir/app.lock")
        let created = try #require(lock(SingleInstanceLock.acquire(at: file)))
        #expect(FileManager.default.fileExists(atPath: file.path))
        created.release()
    }

    @Test func aLockThatCannotBeCreatedIsAFailureNotAnotherCopy() throws {
        let sandbox = Sandbox()
        let notAFolder = try sandbox.write("plain file", to: "blocker")
        guard case let .failed(reason) = SingleInstanceLock.acquire(at: notAFolder.appendingPathComponent("app.lock"))
        else {
            Issue.record("a path under a file cannot hold a lock; that is a failure")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test func aLockPathThatIsAFolderIsAFailureNotAnotherCopy() throws {
        let sandbox = Sandbox()
        let folder = sandbox.directory.appendingPathComponent("app.lock")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard case .failed = SingleInstanceLock.acquire(at: folder) else {
            Issue.record("a folder cannot be opened as a lock file; that is a failure")
            return
        }
    }

    @Test func theLockFileIsNamedAfterTheBundleIdentifierInTheUsersTemporaryFolder() {
        let url = SingleInstanceLock.defaultFile(
            identifier: "io.example.app", temporary: URL(fileURLWithPath: "/tmp/x"))
        #expect(url.path == "/tmp/x/io.example.app.lock")
    }
}
