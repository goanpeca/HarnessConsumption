import Foundation
import Testing

/// Tests in this target must never reach the user's real login files, Keychain, defaults or network
/// (the credential-handling policy). They get their own through `Sandbox` and `StubSession`; this
/// check fails if a test file names a real one.
struct TestSafetyTests {
    private static let forbidden: [(needle: String, why: String)] = [
        ("UserDefaults" + ".standard", "use Sandbox().defaults"),
        ("URLSession" + ".shared", "use StubSession"),
        ("homeDirectory" + "ForCurrentUser", "use Sandbox().directory"),
        ("NSHome" + "Directory", "use Sandbox().directory"),
        (".applicationSupport" + "Directory", "use Sandbox().directory"),
    ]

    /// Calls that are only safe with an argument that points somewhere private.
    private static let forbiddenPatterns: [(pattern: String, why: String)] = [
        (#"Keychain\.readPassword\(service:[^,)]*\)"#, "reads the real Keychain: pass a fake tool script with tool:"),
        (
            #"DesktopAuth\.configFile\b(?!\()"#,
            "reads Claude Desktop's real config: use configFile(home:) or a Sandbox file"
        ),
        (
            #"(?s)claudeToken\((?:(?!configFile:)[^)])*\)"#,
            "omits configFile:, which falls back to Claude Desktop's real config"
        ),
        (#"CodexClient\.defaultAuthFile"#, "reads the real Codex login: pass an auth file inside a Sandbox"),
        (#"CodexClient\.authFile\(\)"#, "reads the real Codex login: pass environment and home"),
    ]

    @Test func noTestFileReachesRealCredentialsDefaultsOrNetwork() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files =
            FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter {
                $0.pathExtension == "swift" && $0.lastPathComponent != "TestSafetyTests.swift"
            }
            ?? []
        #expect(files.count >= 3)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (pattern, why) in Self.forbiddenPatterns {
                #expect(!text.contains(try Regex(pattern)), "\(file.lastPathComponent): \(why)")
            }
            for (needle, why) in Self.forbidden {
                #expect(!text.contains(needle), "\(file.lastPathComponent) uses '\(needle)': \(why)")
            }
        }
    }
}
