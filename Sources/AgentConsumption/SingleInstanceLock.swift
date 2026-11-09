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

    enum Outcome {
        case acquired(SingleInstanceLock)
        /// Another process holds it: another copy of the app is running.
        case heldElsewhere
        /// The lock could not be made at all (unwritable folder, unopenable file). Says nothing about
        /// other copies, so it must not be treated as one.
        case failed(String)
    }

    static func acquire(at file: URL) -> Outcome {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return .failed("can't create \(file.deletingLastPathComponent().path): \(error.localizedDescription)")
        }
        let descriptor = open(file.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return .failed("can't open \(file.path): \(String(cString: strerror(errno)))") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(descriptor)
            return code == EWOULDBLOCK
                ? .heldElsewhere : .failed("can't lock \(file.path): \(String(cString: strerror(code)))")
        }
        return .acquired(SingleInstanceLock(descriptor: descriptor))
    }

    /// `<temporary folder>/<bundle identifier>.lock`: one lock per app, per user.
    static func defaultFile(identifier: String, temporary: URL) -> URL {
        temporary.appendingPathComponent("\(identifier).lock")
    }

    func release() {
        close(descriptor)
    }
}
