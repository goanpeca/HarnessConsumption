import Foundation

/// What tests in this target must never do (the credential-handling policy): reach the real login files,
/// Keychain, defaults, support directory or network. `TestSafetyTests` applies these to every test file.
enum SafetyRules {
    /// Names that always reach something real.
    static let forbiddenNames: [(needle: String, why: String)] = [
        ("UserDefaults" + ".standard", "use Sandbox().defaults"),
        ("URLSession" + ".shared", "use StubSession"),
        ("homeDirectory" + "ForCurrentUser", "use Sandbox().directory"),
        ("NSHome" + "Directory", "use Sandbox().directory"),
        (".applicationSupport" + "Directory", "use Sandbox().directory"),
        ("CodexClient.default" + "AuthFile", "pass an auth file inside a Sandbox"),
        ("DesktopAuth.config" + "File\n", "use configFile(home:) or a Sandbox file"),
    ]

    /// Calls that fall back to something real unless every isolating argument is passed.
    struct IsolatedCall {
        let name: String
        let labels: [String]
        let why: String
    }

    static let isolatedCalls: [IsolatedCall] = [
        IsolatedCall(name: "Keychain.readPassword(", labels: ["tool:"], why: "pass a fake tool script"),
        IsolatedCall(
            name: "DesktopAuth.claudeToken(", labels: ["configFile:", "secret:"],
            why: "pass a Sandbox config file and a secret"),
        IsolatedCall(name: "ClaudeClient(", labels: ["token:"], why: "pass a token provider"),
        IsolatedCall(name: "CodexClient(", labels: ["authFile:"], why: "pass an auth file inside a Sandbox"),
        IsolatedCall(
            name: "CodexClient.authFile(", labels: ["environment:", "home:"], why: "pass an environment and a fake home"
        ),
        IsolatedCall(
            name: "UsageStore(", labels: ["defaults:", "supportDirectory:", "holidaySession:", "fetchers:"],
            why: "build it with StoreHarness, or pass defaults, a directory, a stub session and fetchers"),
    ]

    /// Every rule `text` breaks, as readable messages. Nothing in `text` is executed.
    static func violations(in text: String) -> [String] {
        var found = forbiddenNames.filter { text.contains($0.needle) }.map { "uses '\($0.needle)': \($0.why)" }
        let characters = Array(text)
        for call in isolatedCalls {
            for arguments in argumentLists(of: call.name, in: characters) {
                let code = withoutStringContents(arguments)
                let missing = call.labels.filter { !code.contains($0) }
                if !missing.isEmpty {
                    found.append("calls \(call.name) without \(missing.joined(separator: ", ")): \(call.why)")
                }
            }
        }
        return found
    }

    /// The text between the parentheses of each use of `name`, balancing nested parentheses and skipping
    /// string literals. An unterminated call yields an empty list so it is reported as missing arguments.
    private static func argumentLists(of name: String, in characters: [Character]) -> [String] {
        let needle = Array(name)
        var lists: [String] = []
        var index = 0
        while index + needle.count <= characters.count {
            guard Array(characters[index..<index + needle.count]) == needle, startsAWord(at: index, in: characters)
            else {
                index += 1
                continue
            }
            var depth = 1
            var cursor = index + needle.count
            var inString = false
            let start = cursor
            while cursor < characters.count, depth > 0 {
                let character = characters[cursor]
                if character == "\\", inString {
                    cursor += 1
                } else if character == "\"" {
                    inString.toggle()
                } else if !inString, character == "(" {
                    depth += 1
                } else if !inString, character == ")" {
                    depth -= 1
                }
                cursor += 1
            }
            lists.append(depth == 0 ? String(characters[start..<cursor - 1]) : "")
            index = cursor
        }
        return lists
    }

    /// `text` with everything inside double quotes removed, so a label written in a string is not a label.
    private static func withoutStringContents(_ text: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        for character in text {
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// `ClaudeClient(` inside `MyClaudeClient(` or `x.ClaudeClient(` is some other thing.
    private static func startsAWord(at index: Int, in characters: [Character]) -> Bool {
        guard index > 0 else { return true }
        let before = characters[index - 1]
        return !(before.isLetter || before.isNumber || before == "_" || before == ".")
    }
}
