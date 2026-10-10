import Foundation

/// Reads generic passwords through `/usr/bin/security`.
///
/// Going through the system tool keeps Keychain approval tied to it rather than to this ad-hoc-signed
/// app, so rebuilding the app doesn't re-prompt.
enum Keychain {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func readPassword(service: String) throws -> String {
        let output = try run(["find-generic-password", "-s", service, "-w"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let errText = String(decoding: errData, as: UTF8.self)
        guard process.terminationStatus == 0, !errText.contains("error") else {
            throw Failure(description: "security \(arguments.first ?? ""): \(errText)")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
