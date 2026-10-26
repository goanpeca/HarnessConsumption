import Foundation
import Testing

/// Tests in this target must never reach the user's real login files, Keychain, defaults or network (the
/// credential-handling policy). They get their own through `Sandbox` and `StubSession`; this check fails
/// if a test file names a real one, or makes a call that silently falls back to one.
struct TestSafetyTests {
    @Test func noTestFileReachesRealCredentialsDefaultsOrNetwork() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let skipped: Set<String> = ["TestSafetyTests.swift", "SafetyRules.swift"]
        let files =
            FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" && !skipped.contains($0.lastPathComponent) }
            ?? []
        #expect(files.count >= 10)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for violation in SafetyRules.violations(in: text) {
                Issue.record("\(file.lastPathComponent) \(violation)")
            }
        }
    }

    // MARK: the rules themselves, against sample text that is only ever scanned

    private func unsafe(_ text: String, mentions fragment: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let found = SafetyRules.violations(in: text)
        #expect(
            found.contains { $0.contains(fragment) }, "expected a violation mentioning \(fragment): \(found)",
            sourceLocation: sourceLocation)
    }

    @Test func unsafeCallsThatOmitAnIsolatingArgumentAreRejected() {
        unsafe("try DesktopAuth.claudeToken(now: now, configFile: file)", mentions: "secret:")
        unsafe("try DesktopAuth.claudeToken(secret: { \"x\" })", mentions: "configFile:")
        unsafe("try DesktopAuth.claudeToken()", mentions: "configFile:")
        unsafe("ClaudeClient(session: stub.session)", mentions: "token:")
        unsafe("CodexClient(session: stub.session)", mentions: "authFile:")
        unsafe("UsageStore(notifier: notifier)", mentions: "defaults:")
        unsafe("UsageStore(notifier: n, defaults: d, supportDirectory: s)", mentions: "holidaySession:")
        unsafe("Keychain.readPassword(service: \"x\")", mentions: "tool:")
        unsafe("CodexClient.authFile()", mentions: "environment:")
        unsafe("CodexClient.authFile(environment: [:])", mentions: "home:")
    }

    @Test func unsafeNamesAreRejected() {
        unsafe("let d = " + "UserDefaults" + ".standard", mentions: "UserDefaults")
        unsafe("let s = " + "URLSession" + ".shared", mentions: "URLSession")
        unsafe("FileManager.default." + "homeDirectory" + "ForCurrentUser", mentions: "homeDirectory")
    }

    @Test func aCallSplitAcrossLinesAndAnUnterminatedCallAreStillChecked() {
        unsafe("UsageStore(\n    notifier: n,\n    defaults: d\n)", mentions: "supportDirectory:")
        unsafe("ClaudeClient(session: s", mentions: "token:")
    }

    @Test func fullyIsolatedCallsPass() {
        let safe = """
            try DesktopAuth.claudeToken(now: now, configFile: dir.appendingPathComponent("a.json"), secret: { secret })
            ClaudeClient(session: s.session, token: { _ in nil })
            CodexClient(session: s.session, authFile: try auth(sandbox))
            CodexClient.authFile(environment: ["CODEX_HOME": "/x"], home: URL(fileURLWithPath: "/fake"))
            try Keychain.readPassword(service: "svc", tool: tool)
            UsageStore(notifier: n, defaults: d.defaults, supportDirectory: d.directory, holidaySession: h.session, fetchers: [:])
            """
        #expect(SafetyRules.violations(in: safe).isEmpty)
    }

    @Test func parenthesesInsideStringsDoNotConfuseTheScanner() {
        let safe = #"Keychain.readPassword(service: "a (b", tool: t)"#
        #expect(SafetyRules.violations(in: safe).isEmpty)
        unsafe(#"Keychain.readPassword(service: "tool: (x")"#, mentions: "tool:")
    }

    @Test func similarNamesAreNotMistakenForTheGuardedOnes() {
        #expect(SafetyRules.violations(in: "MyClaudeClient(session: s) ; other.ClaudeClient(x)").isEmpty)
        #expect(SafetyRules.violations(in: "struct ClaudeClientTests {").isEmpty)
    }
}
