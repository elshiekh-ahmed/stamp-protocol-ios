import SwiftUI
import XCTest
@testable import JOEYY

@MainActor
final class BusinessStoreTests: XCTestCase {
    private var fileURL: URL!
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUp() async throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JOEYYBusinessTests-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: fileURL)
        fileURL = nil
    }

    private func makeStore() -> PartnerStore {
        let fixed = now
        return PartnerStore(fileURL: fileURL, now: { fixed })
    }

    private func validDraft(punches: Int = 10, reward: String = "One handcrafted drink") -> ProgramDraft {
        var draft = ProgramDraft.starter
        draft.requiredPunches = punches
        draft.rewardDescription = reward
        return draft
    }

    func testStartsEmptyWithoutSavedData() {
        let store = makeStore()
        XCTAssertNil(store.business)
        XCTAssertNil(store.currentProgram)
        XCTAssertEqual(store.summary(for: .all), .zero)
    }

    func testSaveBusinessCreatesThenUpdatesTheSameRecord() throws {
        let store = makeStore()
        let created = try store.saveBusiness(name: "  Norema Cafe ", location: "Capitol Hill, Seattle, WA", logoPNG: nil)
        XCTAssertEqual(created.name, "Norema Cafe")
        XCTAssertEqual(created.ownerSubject, PartnerStore.localOwnerSubject)
        XCTAssertNil(created.currentProgramVersionID)

        let logo = Data([1, 2, 3])
        let updated = try store.saveBusiness(name: "Norema Coffee", location: "", logoPNG: logo)
        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(updated.name, "Norema Coffee")
        XCTAssertEqual(updated.logoPNG, logo)
    }

    func testSaveBusinessValidatesInput() {
        let store = makeStore()
        XCTAssertThrowsError(try store.saveBusiness(name: "   ", location: "", logoPNG: nil)) {
            XCTAssertEqual($0 as? PartnerError, .missingName)
        }
        let longName = String(repeating: "a", count: Business.nameLimit + 1)
        XCTAssertThrowsError(try store.saveBusiness(name: longName, location: "", logoPNG: nil)) {
            XCTAssertEqual($0 as? PartnerError, .nameTooLong)
        }
        XCTAssertNil(store.business)
    }

    func testPublishRequiresBusinessAndValidRules() throws {
        let store = makeStore()
        XCTAssertThrowsError(try store.publish(validDraft())) {
            XCTAssertEqual($0 as? PartnerError, .missingBusiness)
        }
        try store.saveBusiness(name: "Norema Cafe", location: "", logoPNG: nil)
        XCTAssertThrowsError(try store.publish(validDraft(punches: 2))) {
            XCTAssertEqual($0 as? PartnerError, .invalidPunches)
        }
        XCTAssertThrowsError(try store.publish(validDraft(punches: 13))) {
            XCTAssertEqual($0 as? PartnerError, .invalidPunches)
        }
        XCTAssertThrowsError(try store.publish(validDraft(reward: "  "))) {
            XCTAssertEqual($0 as? PartnerError, .missingReward)
        }
        var unreadable = validDraft()
        unreadable.design.theme.lightInk = unreadable.design.theme.lightPaper
        XCTAssertThrowsError(try store.publish(unreadable)) {
            XCTAssertEqual($0 as? PartnerError, .invalidTheme)
        }
        XCTAssertTrue(store.versionsNewestFirst.isEmpty)
    }

    func testPublishingCreatesImmutableVersionsAndExistingCardsKeepTheirRules() throws {
        let store = makeStore()
        store.loadNoremaSample()
        let original = try XCTUnwrap(store.currentProgram)
        XCTAssertEqual(original.version, 1)
        XCTAssertEqual(original.requiredPunches, 10)
        let usageBefore = store.usage(of: original)
        XCTAssertEqual(usageBefore.status, .live)
        XCTAssertGreaterThan(usageBefore.inProgress, 0)
        XCTAssertGreaterThan(usageBefore.completed, 0)
        XCTAssertEqual(store.cardsFinishingOlderVersions, 0)
        let impact = store.publishImpact()
        XCTAssertEqual(impact.keepRules + impact.switchToNew, usageBefore.inProgress)
        XCTAssertGreaterThan(impact.keepRules, 0)
        XCTAssertGreaterThan(impact.switchToNew, 0, "Sample data includes fresh cards with no punches")
        let startedCards = store.state.cards.filter { $0.status == .active && $0.punches > 0 }

        var draft = ProgramDraft(version: original)
        XCTAssertThrowsError(try store.publish(draft)) {
            XCTAssertEqual($0 as? PartnerError, .unchangedProgram)
        }

        draft.requiredPunches = 8
        draft.rewardDescription = "  Any pastry  "
        let second = try store.publish(draft)
        XCTAssertEqual(second.version, 2)
        XCTAssertEqual(second.requiredPunches, 8)
        XCTAssertEqual(second.rewardDescription, "Any pastry")
        XCTAssertEqual(second.publishedAt, now)
        XCTAssertEqual(store.currentProgram, second)
        XCTAssertEqual(store.versionsNewestFirst.map(\.version), [2, 1])
        XCTAssertEqual(store.versionsNewestFirst.last, original, "Published versions are never edited")

        // Cards with punches keep version 1; cards with no punches move to version 2.
        let usageAfter = store.usage(of: original)
        XCTAssertEqual(usageAfter.status, .finishing)
        XCTAssertEqual(usageAfter.inProgress, impact.keepRules)
        XCTAssertEqual(usageAfter.completed, usageBefore.completed)
        XCTAssertEqual(store.cardsFinishingOlderVersions, impact.keepRules)
        XCTAssertEqual(
            store.usage(of: second),
            VersionUsage(status: .live, inProgress: impact.switchToNew, completed: 0)
        )
        for card in startedCards {
            XCTAssertEqual(store.state.cards.first { $0.id == card.id }?.programVersionID, original.id)
        }
        XCTAssertTrue(store.state.cards.filter { $0.status == .active && $0.punches == 0 }
            .allSatisfy { $0.programVersionID == second.id })

        // Publishing again moves the unstarted cards on; an older version with none left is retired.
        draft.requiredPunches = 6
        let third = try store.publish(draft)
        XCTAssertEqual(store.usage(of: second).status, .retired)
        XCTAssertEqual(store.usage(of: original).status, .finishing)
        XCTAssertEqual(store.usage(of: third), VersionUsage(status: .live, inProgress: impact.switchToNew, completed: 0))
    }

    func testLocationIsValidatedAndFormatted() throws {
        let store = makeStore()
        let tooLong = String(repeating: "a", count: Business.locationLimit + 1)
        XCTAssertThrowsError(try store.saveBusiness(name: "Norema Cafe", location: tooLong, logoPNG: nil)) {
            XCTAssertEqual($0 as? PartnerError, .locationTooLong)
        }
        let city = LocationSuggestion(title: "Seattle", subtitle: "WA, United States")
        XCTAssertEqual(city.formatted, "Seattle, WA, United States")
        XCTAssertEqual(LocationSuggestion(title: "Seattle", subtitle: "").formatted, "Seattle")
        let saved = try store.saveBusiness(name: "Norema Cafe", location: city.formatted, logoPNG: nil)
        XCTAssertEqual(saved.location, "Seattle, WA, United States")
    }

    func testDashboardCountsUseHalfOpenRangesAndUniqueCustomers() throws {
        let store = makeStore()
        store.loadNoremaSample()
        let state = store.state
        let start = now.addingTimeInterval(-30 * 86_400)

        let summary = store.summary(from: start, to: now)
        XCTAssertEqual(summary.enrolledCardholders, Set(state.cards.map(\.customerID)).count)
        XCTAssertEqual(summary.enrolledCardholders, SampleData.customerCount)
        XCTAssertEqual(summary.punches, state.punches.filter { $0.occurredAt >= start && $0.occurredAt < now }.count)
        XCTAssertEqual(summary.rewardsEarned, state.rewards.filter { $0.earnedAt >= start && $0.earnedAt < now }.count)
        XCTAssertEqual(
            summary.rewardsRedeemed,
            state.rewards.filter { reward in
                guard let redeemedAt = reward.redeemedAt else { return false }
                return redeemedAt >= start && redeemedAt < now
            }.count
        )

        let firstPunch = try XCTUnwrap(state.punches.first)
        XCTAssertEqual(store.summary(from: firstPunch.occurredAt, to: firstPunch.occurredAt).punches, 0)
        XCTAssertGreaterThanOrEqual(store.summary(from: firstPunch.occurredAt, to: now).punches, 1)

        let all = store.summary(for: .all)
        XCTAssertEqual(all.punches, state.punches.count)
        XCTAssertEqual(all.rewardsEarned, state.rewards.count)
        XCTAssertLessThanOrEqual(all.rewardsRedeemed, all.rewardsEarned)
        XCTAssertGreaterThan(all.rewardsRedeemed, 0)
    }

    func testSampleDataIsInternallyConsistent() throws {
        let data = SampleData.norema(now: now, logoPNG: nil)
        XCTAssertEqual(data, SampleData.norema(now: now, logoPNG: nil), "Sample data is deterministic")
        let version = try XCTUnwrap(data.versions.first)
        for card in data.cards {
            let cardPunches = data.punches.filter { $0.cardID == card.id }.count
            XCTAssertEqual(card.punches, cardPunches)
            XCTAssertLessThanOrEqual(card.punches, version.requiredPunches)
            XCTAssertEqual(card.status == .completed, card.punches == version.requiredPunches)
            XCTAssertLessThan(card.createdAt, now)
        }
        XCTAssertEqual(data.rewards.count, data.cards.filter { $0.status == .completed }.count)
        XCTAssertEqual(Set(data.punches.map(\.eventID)).count, data.punches.count, "Event IDs are unique")
        for reward in data.rewards {
            XCTAssertLessThan(reward.earnedAt, now)
            if let redeemedAt = reward.redeemedAt {
                XCTAssertGreaterThan(redeemedAt, reward.earnedAt)
                XCTAssertLessThan(redeemedAt, now)
            }
        }
        XCTAssertTrue(data.punches.allSatisfy { $0.occurredAt < now })
    }

    func testDataPersistsAcrossLaunches() throws {
        let store = makeStore()
        try store.saveBusiness(name: "Norema Cafe", location: "Seattle, WA, United States", logoPNG: nil)
        let version = try store.publish(validDraft())

        let reopened = makeStore()
        XCTAssertEqual(reopened.business?.name, "Norema Cafe")
        XCTAssertEqual(reopened.currentProgram, version)
        XCTAssertNil(reopened.storageError)

        reopened.startOver()
        XCTAssertNil(makeStore().business)
    }

    func testUnreadableSavedDataReportsError() throws {
        try Data("not json".utf8).write(to: fileURL)
        let store = makeStore()
        XCTAssertNil(store.business)
        XCTAssertNotNil(store.storageError)
        store.loadNoremaSample()
        XCTAssertNil(store.storageError)
        XCTAssertEqual(store.business?.name, "Norema Cafe")
    }

    func testEveryPalettePassesTheCustomerAppsContrastCheck() throws {
        for palette in CardPalette.all {
            var theme = CardDesign.starter.theme
            palette.apply(to: &theme)
            XCTAssertNoThrow(try theme.validate(), palette.name)
            XCTAssertTrue(palette.matches(theme))
        }
        XCTAssertTrue(CardPalette.all.contains { $0.matches(CardDesign.starter.theme) })
        XCTAssertEqual(Set(CardPalette.all.map(\.name)).count, CardPalette.all.count)
    }

    func testPreviewPlaceUsesTheDraftsRulesAndCardStock() throws {
        let store = makeStore()
        let business = try store.saveBusiness(name: "Norema Cafe", location: "Seattle, WA", logoPNG: nil)
        let place = Place.businessPreview(business: business, requiredPunches: 8, reward: "Latte", artwork: .stone)
        XCTAssertEqual(place.name, "Norema Cafe")
        XCTAssertEqual(place.requiredPunches, 8)
        XCTAssertEqual(place.rewardDescription, "Latte")
        XCTAssertEqual(place.cardStyle, .stone)
        XCTAssertEqual(Place.businessPreview(business: nil, requiredPunches: 40, reward: "", artwork: .rail).requiredPunches, 12)
        XCTAssertEqual(ProgramDraft.punchRange, Place.punchRange)
    }

    func testDesignChangesAloneCreateANewVersion() throws {
        let store = makeStore()
        store.loadNoremaSample()
        let original = try XCTUnwrap(store.currentProgram)
        var draft = ProgramDraft(version: original)
        draft.design.theme.typeface = .rounded
        draft.design.theme.artwork = .rail
        CardPalette.all[1].apply(to: &draft.design.theme)
        let second = try store.publish(draft)
        XCTAssertEqual(second.design.theme.typeface, .rounded)
        XCTAssertEqual(second.design.theme.artwork, .rail)
        XCTAssertEqual(second.requiredPunches, original.requiredPunches)
        XCTAssertEqual(store.versionsNewestFirst.last?.design, original.design)
    }

    func testBugReportURLIncludesDiagnosticsAndEncodesText() throws {
        let diagnostics = BugReport.Diagnostics(
            appVersion: "0.1.0", build: "7", device: "iPhone16,1", system: "iOS 18.5",
            screen: "Card designer", appearance: "System / Orange", reportedAt: now
        )
        let body = BugReport.body(
            whatHappened: "Publish & preview disagree", expected: "", steps: "1. Open Card\n2. Tap +",
            diagnostics: diagnostics
        )
        XCTAssertTrue(body.contains("| Screen | Card designer |"))
        XCTAssertTrue(body.contains("| App | JOEYY 0.1.0 (7), business side |"))
        XCTAssertTrue(body.contains("_Not provided_"))

        let url = try XCTUnwrap(BugReport.issueURL(title: " Stepper + wallet? ", body: body))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "github.com")
        XCTAssertEqual(components.path, "/\(BugReport.repository)/issues/new")
        XCTAssertFalse(url.absoluteString.contains("+"), "Plus signs are percent-encoded")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["title"], "Stepper + wallet?")
        XCTAssertEqual(items["body"], body)
        XCTAssertEqual(items["labels"], "bug")
    }
}
