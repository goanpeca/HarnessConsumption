import Foundation

/// Reads and writes generic passwords through `/usr/bin/security`.
///
/// Claude Code stores its login with `security`, so that tool is already on the item's access list:
/// going through it avoids a Keychain prompt on every rebuild of this ad-hoc-signed app.
enum Keychain {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func readPassword(service: String) throws -> String {
        let output = try run(["find-generic-password", "-s", service, "-w"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func account(service: String) throws -> String {
        let output = try run(["find-generic-password", "-s", service])
        guard let line = output.split(separator: "\n").first(where: { $0.contains("\"acct\"") }),
              let value = line.split(separator: "=", maxSplits: 1).last else {
            throw Failure(description: "No account on Keychain item \(service)")
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }

    /// Updates the item in place. The secret goes through stdin as hex, never through argv.
    static func updatePassword(service: String, account: String, password: String) throws {
        let hex = password.utf8.map { String(format: "%02x", $0) }.joined()
        let command = "add-generic-password -U -a \"\(account)\" -s \"\(service)\" -X \(hex)\n"
        _ = try run(["-i"], stdin: command)
    }

    private static func run(_ arguments: [String], stdin: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        let input = Pipe()
        if stdin != nil { process.standardInput = input }
        try process.run()
        if let stdin {
            input.fileHandleForWriting.write(Data(stdin.utf8))
            try input.fileHandleForWriting.close()
        }
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
