import Foundation
import Testing

@testable import AgentConsumption

/// Only one copy of the app may create a menu bar item: a second one makes macOS mark the item as
/// removed for good. The lock is the operating system's, so two launches at the same instant cannot
/// both win, or both lose.
struct SingleInstanceLockTests {
    @Test func theFirstLaunchTakesTheLockAndASecondIsRefused() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("app.lock")
        let first = try #require(SingleInstanceLock.acquire(at: file))
        #expect(SingleInstanceLock.acquire(at: file) == nil)
        first.release()
    }

    @Test func releasingTheLockLetsTheNextLaunchTakeIt() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("app.lock")
        try #require(SingleInstanceLock.acquire(at: file)).release()
        let next = try #require(SingleInstanceLock.acquire(at: file))
        next.release()
    }

    @Test func differentAppsDoNotShareALock() throws {
        let sandbox = Sandbox()
        let one = try #require(SingleInstanceLock.acquire(at: sandbox.directory.appendingPathComponent("a.lock")))
        let other = try #require(SingleInstanceLock.acquire(at: sandbox.directory.appendingPathComponent("b.lock")))
        one.release()
        other.release()
    }

    @Test func manySimultaneousLaunchesProduceExactlyOneWinner() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("race.lock")
        let winners = LockedBox<[SingleInstanceLock]>([])
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            if let lock = SingleInstanceLock.acquire(at: file) { winners.value.append(lock) }
        }
        #expect(winners.value.count == 1)
        winners.value.forEach { $0.release() }
    }

    @Test func aLockInAMissingFolderIsCreatedThere() throws {
        let sandbox = Sandbox()
        let file = sandbox.directory.appendingPathComponent("nested/dir/app.lock")
        let lock = try #require(SingleInstanceLock.acquire(at: file))
        #expect(FileManager.default.fileExists(atPath: file.path))
        lock.release()
    }

    @Test func theLockFileIsNamedAfterTheBundleIdentifierInTheUsersTemporaryFolder() {
        let url = SingleInstanceLock.defaultFile(
            identifier: "io.example.app", temporary: URL(fileURLWithPath: "/tmp/x"))
        #expect(url.path == "/tmp/x/io.example.app.lock")
    }
}
