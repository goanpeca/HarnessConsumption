import Foundation
import Testing

@testable import AgentConsumption

/// `Keychain` shells out to `/usr/bin/security`; these tests point it at throwaway scripts instead, so
/// they check how it builds the command and reads the result without touching the real Keychain.
struct KeychainTests {
    private func script(_ body: String, in sandbox: Sandbox) throws -> URL {
        let url = try sandbox.write("#!/bin/sh\n\(body)\n", to: "fake-security-\(UUID())")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @Test func returnsTheSecretWithSurroundingWhitespaceTrimmed() throws {
        let sandbox = Sandbox()
        let tool = try script("printf '  s3cret-value \\n\\n'", in: sandbox)
        #expect(try Keychain.readPassword(service: "svc", tool: tool) == "s3cret-value")
    }

    @Test func asksForTheGenericPasswordOfTheNamedServiceAndOnlyThat() throws {
        let sandbox = Sandbox()
        let tool = try script(#"printf '%s\n' "$@""#, in: sandbox)
        let echoed = try Keychain.readPassword(service: "My Service", tool: tool)
        #expect(echoed.split(separator: "\n").map(String.init) == ["find-generic-password", "-s", "My Service", "-w"])
    }

    @Test func aNonZeroExitIsAFailureThatNamesTheSubcommandAndTheReason() throws {
        let sandbox = Sandbox()
        let tool = try script("echo 'item could not be found' >&2; exit 44", in: sandbox)
        do {
            _ = try Keychain.readPassword(service: "svc", tool: tool)
            Issue.record("expected a failure")
        } catch let failure as Keychain.Failure {
            #expect(failure.description.hasPrefix("security find-generic-password: "))
            #expect(failure.description.contains("item could not be found"))
        }
    }

    @Test func anErrorOnStderrIsAFailureEvenWhenTheExitCodeIsZero() throws {
        let sandbox = Sandbox()
        let tool = try script("echo 'SecKeychain error' >&2; echo leaked-secret", in: sandbox)
        #expect(throws: Keychain.Failure.self) { try Keychain.readPassword(service: "svc", tool: tool) }
    }

    @Test func aFailureMessageNeverContainsTheSecretFromStdout() throws {
        let sandbox = Sandbox()
        let tool = try script("echo top-secret-output; echo 'boom' >&2; exit 1", in: sandbox)
        do {
            _ = try Keychain.readPassword(service: "svc", tool: tool)
            Issue.record("expected a failure")
        } catch {
            #expect(!"\(error)".contains("top-secret-output"))
        }
    }

    @Test func quietStderrWithoutAnErrorWordIsFine() throws {
        let sandbox = Sandbox()
        let tool = try script("echo 'note: using cache' >&2; echo the-secret", in: sandbox)
        #expect(try Keychain.readPassword(service: "svc", tool: tool) == "the-secret")
    }

    @Test func aMissingToolThrows() {
        let sandbox = Sandbox()
        #expect(throws: (any Error).self) {
            try Keychain.readPassword(service: "svc", tool: sandbox.directory.appendingPathComponent("nope"))
        }
    }

    @Test func theDefaultToolIsTheSystemSecurityBinary() {
        #expect(Keychain.securityTool.path == "/usr/bin/security")
    }

    @Test func failureDescriptionsAreReadable() {
        #expect("\(Keychain.Failure(description: "bad"))" == "bad")
    }

    @Test func aLargeStdoutDoesNotDeadlock() throws {
        let sandbox = Sandbox()
        let tool = try script("head -c 300000 /dev/zero | tr '\\0' 'a'", in: sandbox)
        #expect(try Keychain.readPassword(service: "svc", tool: tool).count == 300_000)
    }
}
