import Foundation
import Testing

@testable import ConsumptionKit

/// The usage endpoints are undocumented and will change. Whatever they send, a parser must either throw
/// or return readings that are safe to show (percentages inside 0...100); it must never crash.
struct ParserRobustnessTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)

    static let validClaude =
        #"{"five_hour":{"utilization":37.0,"resets_at":"2026-10-07T18:00:00.123456+00:00"},"seven_day":{"utilization":62.5,"resets_at":"2026-10-10T03:00:00Z"},"extra_usage":{"utilization":14.3,"used_credits":60400,"monthly_limit":420000,"currency":"USD","decimal_places":2}}"#
    static let validCodex =
        #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":12,"limit_window_seconds":604800,"reset_at":1791985929},"secondary_window":null},"spend_control":{"individual_limit":{"limit":"42858","used":"1903.5","used_percent":4,"reset_at":1793491200}}}"#

    private func safe(_ usage: ProviderUsage) -> Bool {
        usage.windows.allSatisfy { (0...100).contains($0.usedPercent) && !$0.usedPercent.isNaN && $0.length > 0 }
    }

    private func claudeIsSafe(_ data: Data) -> Bool {
        (try? ClaudeUsageParser.parse(data, plan: nil, now: now)).map(safe) ?? true
    }

    private func codexIsSafe(_ data: Data) -> Bool {
        (try? CodexUsageParser.parse(data, now: now)).map(safe) ?? true
    }

    @Test func randomBytesNeverCrashEitherParser() {
        var rng = SeededGenerator(seed: 0xF022)
        for i in 0..<500 {
            let bytes = (0..<Int.random(in: 0...400, using: &rng)).map { _ in UInt8.random(in: 0...255, using: &rng) }
            #expect(claudeIsSafe(Data(bytes)) && codexIsSafe(Data(bytes)), "seed F022 round \(i)")
        }
    }

    @Test func jsonShapedNoiseNeverCrashesEitherParser() {
        var rng = SeededGenerator(seed: 0x7E57)
        let alphabet = Array(#"{}[]":,.-+eE0123456789 truefalsenull_abcxyz\/"#)
        for i in 0..<500 {
            let text = String(
                (0..<Int.random(in: 0...300, using: &rng)).compactMap { _ in alphabet.randomElement(using: &rng) })
            let data = Data(text.utf8)
            #expect(claudeIsSafe(data) && codexIsSafe(data), "seed 7E57 round \(i): \(text)")
        }
    }

    @Test func everyTruncationOfAValidPayloadIsHandled() {
        for payload in [Self.validClaude, Self.validCodex] {
            let bytes = Array(payload.utf8)
            for length in 0..<bytes.count {
                let data = Data(bytes.prefix(length))
                #expect(claudeIsSafe(data) && codexIsSafe(data), "truncated at \(length)")
            }
        }
    }

    @Test func everySingleCharacterMutationOfAValidPayloadIsHandled() {
        var rng = SeededGenerator(seed: 0x3A7)
        let replacements = Array(#"{}[]":,.-9xnul "#.utf8)
        for payload in [Self.validClaude, Self.validCodex] {
            let bytes = Array(payload.utf8)
            for index in 0..<bytes.count {
                var mutated = bytes
                mutated[index] = replacements.randomElement(using: &rng) ?? 0x20
                #expect(claudeIsSafe(Data(mutated)) && codexIsSafe(Data(mutated)), "mutated byte \(index)")
            }
        }
    }

    @Test func outOfRangeNumbersAreClampedNotTrusted() throws {
        let claude =
            #"{"five_hour":{"utilization":-40,"resets_at":null},"seven_day":{"utilization":1e9,"resets_at":null}}"#
        let usage = try ClaudeUsageParser.parse(Data(claude.utf8), plan: nil, now: now)
        #expect(usage.session?.usedPercent == 0)
        #expect(usage.weekly?.usedPercent == 100)
        let codex = #"{"rate_limit":{"primary_window":{"used_percent":250}}}"#
        #expect(try CodexUsageParser.parse(Data(codex.utf8), now: now).weekly?.usedPercent == 100)
    }

    @Test func anUnparsableResetDateIsNilNotACrash() throws {
        let json = #"{"five_hour":{"utilization":10,"resets_at":"next tuesday"},"seven_day":null}"#
        #expect(try ClaudeUsageParser.parse(Data(json.utf8), plan: nil, now: now).session?.resetsAt == nil)
    }

    @Test func wrongTypesAreRejected() {
        for body in [
            #"{"five_hour":{"utilization":"high"}}"#, #"{"five_hour":[1,2]}"#, #"[]"#, #"null"#, #""text""#, #"42"#,
        ] {
            #expect(throws: UsageParseError.self) { try ClaudeUsageParser.parse(Data(body.utf8), plan: nil, now: now) }
        }
        for body in [#"{"rate_limit":{"primary_window":{"used_percent":"12"}}}"#, #"[]"#, #"null"#] {
            #expect(throws: UsageParseError.self) { try CodexUsageParser.parse(Data(body.utf8), now: now) }
        }
    }

    @Test func aHugeLimitThatCannotBeADoubleStillDoesNotCrash() {
        let json =
            #"{"rate_limit":null,"spend_control":{"individual_limit":{"limit":"1e999","used":"-1e999","used_percent":5,"reset_at":1793491200}}}"#
        #expect(codexIsSafe(Data(json.utf8)))
    }

    @Test func holidayAndCountryPayloadsNeverCrash() {
        var rng = SeededGenerator(seed: 0x401D)
        for i in 0..<300 {
            let bytes = (0..<Int.random(in: 0...200, using: &rng)).map { _ in UInt8.random(in: 32...126, using: &rng) }
            _ = try? HolidayStore.parse(Data(bytes))
            _ = try? HolidayStore.parseCountries(Data(bytes))
            _ = i
        }
        #expect(throws: (any Error).self) { try HolidayStore.parse(Data(#"[{"date":"not-a-date"}]"#.utf8)) }
        #expect(throws: (any Error).self) { try HolidayStore.parse(Data(#"[{"date":"2026-02-30"}]"#.utf8)) }
    }
}
