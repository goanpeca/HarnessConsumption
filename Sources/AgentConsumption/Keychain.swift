import Foundation

/// Reads generic passwords through `/usr/bin/security`.
///
/// Going through the system tool keeps Keychain approval tied to it rather than to this ad-hoc-signed
/// app, so rebuilding the app doesn't re-prompt.
enum Keychain {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static let securityTool = URL(fileURLWithPath: "/usr/bin/security")

    /// `tool` is only ever replaced in tests, which must not reach the real Keychain.
    static func readPassword(service: String, tool: URL = Self.securityTool) throws -> String {
        let output = try run(["find-generic-password", "-s", service, "-w"], tool: tool)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func run(_ arguments: [String], tool: URL) throws -> String {
        let process = Process()
        process.executableURL = tool
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
