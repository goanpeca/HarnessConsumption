import Foundation
import Testing

@testable import ConsumptionKit

struct ParsingTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)

    @Test func parsesCodexWeeklyWindow() throws {
        let json = #"""
            {"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,
             "primary_window":{"used_percent":12,"limit_window_seconds":604800,"reset_after_seconds":602641,"reset_at":1791985929},
             "secondary_window":null}}
            """#
        let usage = try CodexUsageParser.parse(Data(json.utf8), now: now)
        #expect(usage.provider == .codex)
        #expect(usage.plan == "pro")
        #expect(
            usage.weekly
                == UsageWindow(
                    kind: .weekly, usedPercent: 12,
                    resetsAt: Date(timeIntervalSince1970: 1_791_985_929), length: 604_800))
        #expect(usage.session == nil)
    }

    @Test func parsesCodexSessionAndWeekly() throws {
        let json = #"""
            {"rate_limit":{"primary_window":{"used_percent":40,"limit_window_seconds":18000,"reset_after_seconds":600},
                           "secondary_window":{"used_percent":5,"limit_window_seconds":604800,"reset_at":1791985929}}}
            """#
        let usage = try CodexUsageParser.parse(Data(json.utf8), now: now)
        #expect(usage.session?.usedPercent == 40)
        #expect(usage.session?.resetsAt == now.addingTimeInterval(600))
        #expect(usage.weekly?.usedPercent == 5)
    }

    @Test func parsesCodexSpendLimitWhenNoRateLimit() throws {
        let json = #"""
            {"plan_type":"enterprise","rate_limit":null,"credits":{"has_credits":true,"balance":null},
             "spend_control":{"reached":false,"individual_limit":{"source":"org","unit":"credits",
              "used_percent":1,"remaining_percent":99,"reset_after_seconds":1834820,"reset_at":1793491200}}}
            """#
        let usage = try CodexUsageParser.parse(Data(json.utf8), now: now)
        #expect(usage.weekly == nil)
        #expect(
            usage.monthly
                == UsageWindow(
                    kind: .monthly, usedPercent: 1, resetsAt: Date(timeIntervalSince1970: 1_793_491_200)))
        #expect(usage.plan == "enterprise")
    }

    @Test func parsesClaudeUsage() throws {
        let json = #"""
            {"five_hour":{"utilization":37.0,"resets_at":"2026-10-07T18:00:00.123456+00:00"},
             "seven_day":{"utilization":62.5,"resets_at":"2026-10-10T03:00:00Z"},
             "seven_day_opus":null}
            """#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: "max", now: now)
        #expect(usage.session?.usedPercent == 37)
        #expect(usage.weekly?.usedPercent == 62.5)
        #expect(usage.weekly?.remainingPercent == 37.5)
        #expect(usage.weekly?.resetsAt == ClaudeUsageParser.parseISODate("2026-10-10T03:00:00Z"))
        #expect(usage.session?.resetsAt != nil)
    }

    @Test func parsesClaudeMonthlySpendWhenNoWindows() throws {
        let json = #"""
            {"five_hour":null,"seven_day":null,
             "extra_usage":{"is_enabled":true,"monthly_limit":420000,"used_credits":60400.0,
                            "utilization":14.38,"currency":"USD"}}
            """#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: "enterprise", now: now)
        #expect(usage.session == nil)
        #expect(usage.weekly == nil)
        #expect(usage.monthly?.usedPercent == 14.38)
        #expect(usage.monthly?.resetsAt == Date(timeIntervalSince1970: 1_793_491_200))
    }

    @Test func claudeIdleSessionHasNoReset() throws {
        let json = #"{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":3,"resets_at":null}}"#
        let usage = try ClaudeUsageParser.parse(Data(json.utf8), plan: nil, now: now)
        #expect(usage.session?.resetsAt == nil)
    }

    @Test func rejectsPayloadWithoutWindows() {
        #expect(throws: UsageParseError.self) {
            try ClaudeUsageParser.parse(Data(#"{"error":"nope"}"#.utf8), plan: nil, now: now)
        }
        #expect(throws: UsageParseError.self) {
            try CodexUsageParser.parse(Data(#"{"rate_limit":null}"#.utf8), now: now)
        }
    }
}
