import Foundation

/// An exclusive `flock` on a file, held for as long as the app runs. The operating system grants it to
/// exactly one process at a time, so two launches at the same instant cannot both start (or both give
/// up), which a look at the running applications cannot promise. The lock goes away with the process,
/// even if it crashes.
final class SingleInstanceLock: @unchecked Sendable {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    /// The lock at `file`, or nil when another process holds it.
    static func acquire(at file: URL) -> SingleInstanceLock? {
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(file.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return SingleInstanceLock(descriptor: descriptor)
    }

    /// `<temporary folder>/<bundle identifier>.lock`: one lock per app, per user.
    static func defaultFile(identifier: String, temporary: URL) -> URL {
        temporary.appendingPathComponent("\(identifier).lock")
    }

    func release() {
        close(descriptor)
    }
}
