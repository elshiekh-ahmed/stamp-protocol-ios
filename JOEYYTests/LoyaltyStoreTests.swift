import XCTest
import SwiftUI
@testable import JOEYY

@MainActor
final class LoyaltyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var store: LoyaltyStore!
    private let key = "joeyy.memberships.v2"

    override func setUp() async throws {
        suite = "JOEYYTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        store = LoyaltyStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        store = nil
        defaults = nil
    }

    func testRealBusinessSeedsHaveOneRewardAndBoundedTargets() {
        XCTAssertEqual(store.activePlaces.map(\.name), [
            "Monorail Espresso", "Cloud City Coffee", "5 Stones Coffee Co"
        ])
        XCTAssertEqual(store.memberships.map(\.stamps), [5, 6, 2])
        XCTAssertEqual(Place.samples.map(\.requiredPunches), [8, 6, 10])
        XCTAssertEqual(Place.samples.map(\.rewardDescription), ["Espresso", "Brewed coffee", "Latte"])
        XCTAssertEqual(Place.samples.filter { $0.neighborhood.hasPrefix("Seattle") }.count, 2)
        XCTAssertEqual(Place.samples.filter { $0.neighborhood.hasPrefix("Kirkland") }.count, 1)
        for place in Place.samples {
            XCTAssertTrue(Place.punchRange.contains(place.requiredPunches))
            XCTAssertFalse(place.rewardDescription.isEmpty)
            XCTAssertNotNil(UUID(uuidString: place.clientID))
            XCTAssertEqual(URL(string: place.website)?.scheme, "https")
        }
        XCTAssertEqual(Set(Place.samples.map(\.clientID)).count, 3)
        XCTAssertEqual(Set(Place.samples.map(\.id)).count, 3)
        XCTAssertEqual(store.redemptions.count, 3)
        XCTAssertTrue(store.redemptions.allSatisfy(\.isAvailable))
    }

    func testCollectingToFullPersistsWithoutIssuingOrResetting() throws {
        let place = Place.samples[0]
        let coupons = store.redemptions
        for _ in 0..<3 { try store.addStamp(to: place) }
        XCTAssertEqual(store.membership(for: place)?.stamps, 8)
        XCTAssertEqual(store.redemptions, coupons)
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertNil(restored.storageError)
        XCTAssertEqual(restored.memberships, store.memberships)
        XCTAssertEqual(restored.redemptions, coupons)
    }

    func testFullCardRejectsMoreStampsWithoutChangingHistory() throws {
        let place = Place.samples[1]
        let before = store.memberships
        XCTAssertThrowsError(try store.addStamp(to: place))
        XCTAssertEqual(store.memberships, before)
    }

    func testClaimIssuesOneCouponResetsCardAndPersists() throws {
        let place = Place.samples[1]
        let previousCount = try XCTUnwrap(store.membership(for: place)).events.count
        let coupon = try store.claimReward(at: place)
        let membership = try XCTUnwrap(store.membership(for: place))
        XCTAssertEqual(membership.stamps, 0)
        XCTAssertEqual(membership.events.count, previousCount + 1)
        XCTAssertEqual(membership.events.first?.kind, .reward)
        XCTAssertEqual(membership.events.first?.rewardTitle, "Brewed coffee")
        XCTAssertEqual(membership.events.first?.stampCost, 6)
        XCTAssertEqual(membership.coupons.first?.id, coupon.id)
        XCTAssertEqual(store.redemptions.first?.id, coupon.id)
        XCTAssertTrue(try XCTUnwrap(store.redemptions.first).isAvailable)
        XCTAssertEqual(LoyaltyStore(defaults: defaults).membership(for: place), membership)
    }

    func testDuplicateAndPrematureClaimsDoNotMutateData() throws {
        let incomplete = Place.samples[0]
        var before = store.memberships
        XCTAssertThrowsError(try store.claimReward(at: incomplete))
        XCTAssertEqual(store.memberships, before)
        let complete = Place.samples[1]
        try store.claimReward(at: complete)
        before = store.memberships
        XCTAssertThrowsError(try store.claimReward(at: complete))
        XCTAssertEqual(store.memberships, before)
    }

    func testNextCardCanCompleteWhilePreviousCouponIsUnused() throws {
        let place = Place.samples[1]
        let first = try store.claimReward(at: place)
        for _ in 0..<place.requiredPunches { try store.addStamp(to: place) }
        let second = try store.claimReward(at: place)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(store.redemptions.contains { $0.id == first.id && $0.isAvailable })
        XCTAssertTrue(store.redemptions.contains { $0.id == second.id && $0.isAvailable })
        XCTAssertEqual(store.membership(for: place)?.stamps, 0)
    }

    func testAlteredProgramCannotChangeClaimTerms() {
        let original = Place.samples[1]
        let altered = Place(
            id: original.id, clientID: original.clientID, name: original.name,
            neighborhood: original.neighborhood, address: original.address,
            requiredPunches: 3, rewardDescription: "Different reward",
            website: original.website, cardStyle: original.cardStyle
        )
        let before = store.memberships
        XCTAssertThrowsError(try store.claimReward(at: altered))
        XCTAssertThrowsError(try store.addStamp(to: altered))
        XCTAssertEqual(store.memberships, before)
    }

    func testUnjoinedAndArchivedCardsCannotCollectOrClaim() {
        let place = Place.samples[1]
        store.setArchived(true, for: place)
        var before = store.memberships
        XCTAssertThrowsError(try store.claimReward(at: place))
        XCTAssertThrowsError(try store.addStamp(to: place))
        XCTAssertEqual(store.memberships, before)
        store.deleteLocalCards()
        before = store.memberships
        XCTAssertThrowsError(try store.claimReward(at: place))
        XCTAssertThrowsError(try store.addStamp(to: place))
        XCTAssertEqual(store.memberships, before)
    }

    func testApprovedFreshStartReplacesOldProgramsButKeepsSettings() throws {
        defaults.removeObject(forKey: key)
        defaults.set(Data("""
        [{"id":"cozy","stamps":17,"archived":false,"events":[]}]
        """.utf8), forKey: "joeyy.memberships.v1")
        defaults.set(true, forKey: "joeyy.coupon-samples.v1")
        defaults.set("Dark", forKey: "appearance")
        defaults.set("Purple", forKey: "accent")
        let updated = LoyaltyStore(defaults: defaults)
        XCTAssertNil(updated.storageError)
        XCTAssertEqual(updated.memberships.map(\.stamps), [5, 6, 2])
        XCTAssertFalse(updated.memberships.contains { $0.id == "cozy" })
        XCTAssertEqual(updated.redemptions.count, 3)
        XCTAssertNil(defaults.object(forKey: "joeyy.memberships.v1"))
        XCTAssertNil(defaults.object(forKey: "joeyy.coupon-samples.v1"))
        XCTAssertEqual(defaults.string(forKey: "appearance"), "Dark")
        XCTAssertEqual(defaults.string(forKey: "accent"), "Purple")
        XCTAssertEqual(LoyaltyStore(defaults: defaults).memberships, updated.memberships)
    }

    func testCouponCanBeUsedOnlyOnceWithoutChangingCardOrHistory() throws {
        let place = Place.samples[1]
        let coupon = try store.claimReward(at: place)
        try store.addStamp(to: place)
        let events = try XCTUnwrap(store.membership(for: place)).events
        try store.useCoupon(coupon.id)
        let entry = try XCTUnwrap(store.redemptions.first { $0.id == coupon.id })
        XCTAssertNotNil(entry.coupon?.usedAt)
        XCTAssertFalse(entry.isAvailable)
        XCTAssertEqual(store.membership(for: place)?.stamps, 1)
        XCTAssertEqual(store.membership(for: place)?.events, events)
        XCTAssertThrowsError(try store.useCoupon(coupon.id))
        XCTAssertEqual(store.redemptions.first { $0.id == coupon.id }, entry)
        XCTAssertEqual(LoyaltyStore(defaults: defaults).redemptions.first { $0.id == coupon.id }, entry)
    }

    func testArchivingDoesNotInvalidateAnIssuedCoupon() throws {
        let entry = try XCTUnwrap(store.redemptions.first)
        store.setArchived(true, for: entry.place)
        XCTAssertFalse(store.activePlaces.contains(entry.place))
        try store.useCoupon(entry.id)
        XCTAssertNotNil(store.redemptions.first { $0.id == entry.id }?.coupon?.usedAt)
    }

    func testUnknownCouponDoesNotChangeAnyData() {
        let before = store.memberships
        XCTAssertThrowsError(try store.useCoupon(UUID()))
        XCTAssertEqual(store.memberships, before)
    }

    func testDeletingPersistsAndResetRestoresSamplesWithoutChangingSettings() {
        defaults.set("Green", forKey: "accent")
        store.deleteLocalCards()
        XCTAssertTrue(store.redemptions.isEmpty)
        XCTAssertTrue(LoyaltyStore(defaults: defaults).memberships.isEmpty)
        store.resetDemo()
        XCTAssertEqual(store.redemptions.count, 3)
        XCTAssertEqual(store.memberships.map(\.stamps), [5, 6, 2])
        XCTAssertEqual(defaults.string(forKey: "accent"), "Green")
    }

    func testCouponRecordsRequireUniqueValidEventsAndUseDates() throws {
        var missing = store.memberships
        missing[0].coupons.append(Coupon(id: UUID()))
        var duplicate = store.memberships
        let event = try XCTUnwrap(duplicate[0].events.first { $0.kind == .reward })
        duplicate[1].events.append(event)
        duplicate[1].coupons.append(try XCTUnwrap(duplicate[0].coupons.first))
        var invalidDate = store.memberships
        invalidDate[0].coupons[0].usedAt = event.date.addingTimeInterval(-1)
        for invalid in [missing, duplicate, invalidDate] {
            let data = try JSONEncoder().encode(invalid)
            defaults.set(data, forKey: key)
            let restored = LoyaltyStore(defaults: defaults)
            XCTAssertNotNil(restored.storageError)
            XCTAssertTrue(restored.redemptions.isEmpty)
            XCTAssertEqual(defaults.data(forKey: key), data)
        }
    }

    func testInvalidSavedMembershipsAreNotReplacedBySamples() throws {
        let valid = Membership(id: Place.samples[0].id, stamps: 5, events: [])
        let invalid = [
            [Membership(id: valid.id, stamps: -1, events: [])],
            [Membership(id: valid.id, stamps: 9, events: [])],
            [Membership(id: valid.id, stamps: Int.max, events: [])],
            [valid, valid],
            [Membership(id: "unknown", stamps: 6, events: [])]
        ]
        for members in invalid {
            let data = try JSONEncoder().encode(members)
            defaults.set(data, forKey: key)
            let restored = LoyaltyStore(defaults: defaults)
            XCTAssertNotNil(restored.storageError)
            XCTAssertTrue(restored.memberships.isEmpty)
            XCTAssertEqual(defaults.data(forKey: key), data)
        }
    }

    func testSearchUsesOnlyBusinessNamesOrExactClientIDs() {
        XCTAssertEqual(Place.search("  mOnOrAiL  "), [Place.samples[0]])
        XCTAssertEqual(Place.search("5 Stones"), [Place.samples[2]])
        for query in ["", " \n ", "Maple Leaf", "Seattle", "Kirkland", "Espresso reward"] {
            XCTAssertTrue(Place.search(query).isEmpty)
        }
        for place in Place.samples {
            XCTAssertEqual(Place.search(" \(place.clientID.lowercased()) "), [place])
        }
        XCTAssertTrue(Place.search("6A2E3D81").isEmpty)
        XCTAssertTrue(Place.search("00000000-0000-0000-0000-000000000000").isEmpty)
    }

    func testDiscoverablePlacesAreSearchableButNotJoinedByDefault() throws {
        XCTAssertEqual(Place.discoverable.count, 3)
        XCTAssertEqual(Set(Place.catalog.map(\.id)).count, 6)
        XCTAssertEqual(Set(Place.catalog.map(\.clientID)).count, 6)
        for place in Place.discoverable {
            XCTAssertNil(store.membership(for: place))
            XCTAssertEqual(Place.search(place.name), [place])
            XCTAssertEqual(Place.search(place.clientID.lowercased()), [place])
            XCTAssertTrue(Place.punchRange.contains(place.requiredPunches))
            try MerchantTheme.sample(for: place).validate()
        }
        XCTAssertEqual(store.activePlaces, Place.samples)
        XCTAssertEqual(store.redemptions.count, 3)
    }

    func testDiscoveredCardsPersistGroupsFavoritesAndRewards() throws {
        let originals = store.memberships
        for place in Place.discoverable {
            store.join(place)
            XCTAssertEqual(store.membership(for: place)?.stamps, 0)
            for _ in 0..<place.requiredPunches { try store.addStamp(to: place) }
            let coupon = try store.claimReward(at: place)
            try store.useCoupon(coupon.id)
            try store.setFavorite(true, for: place)
        }
        let group = try store.saveGroup(name: "New places", placeIDs: Place.discoverable.map(\.id))
        store.setArchived(true, for: Place.discoverable[0])
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertNil(restored.storageError)
        XCTAssertEqual(restored.memberships, store.memberships)
        XCTAssertEqual(restored.groups, [group])
        XCTAssertEqual(restored.redemptions.count, 6)
        XCTAssertEqual(restored.activePlaces.count, 5)
        for original in originals {
            XCTAssertEqual(restored.memberships.first { $0.id == original.id }, original)
        }
        for place in Place.discoverable {
            XCTAssertEqual(restored.membership(for: place)?.stamps, 0)
            XCTAssertEqual(restored.membership(for: place)?.isFavorite, true)
        }
    }

    func testArchiveRestoreAndDuplicateJoinPreserveStampsAndCoupons() {
        let place = Place.samples[0]
        let before = store.membership(for: place)
        store.setArchived(true, for: place)
        XCTAssertFalse(store.activePlaces.contains(place))
        store.join(place)
        store.join(place)
        XCTAssertEqual(store.memberships.filter { $0.id == place.id }.count, 1)
        XCTAssertEqual(store.membership(for: place), before)
    }

    func testDeletedProgramCanBeRejoinedWithAnEmptyCard() {
        let place = Place.samples[0]
        store.deleteLocalCards()
        store.join(place)
        XCTAssertEqual(store.membership(for: place)?.stamps, 0)
        XCTAssertEqual(store.membership(for: place)?.events.first?.kind, .joined)
        XCTAssertTrue(store.redemptions.isEmpty)
    }

    func testCorruptStorageReportsErrorInsteadOfSeedingOverIt() {
        let data = Data("not JSON".utf8)
        defaults.set(data, forKey: key)
        let corrupt = LoyaltyStore(defaults: defaults)
        XCTAssertNotNil(corrupt.storageError)
        XCTAssertTrue(corrupt.memberships.isEmpty)
        XCTAssertEqual(defaults.data(forKey: key), data)
        corrupt.resetDemo()
        XCTAssertNil(corrupt.storageError)
    }

    func testTextPalettesMeetNormalTextContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(.muted, .paper, style: style), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(.muted, .surface, style: style), 4.5)
            for card in CardStyle.allCases {
                XCTAssertGreaterThanOrEqual(contrast(card.ink, card.paper, style: style), 4.5)
            }

            for accent in AppAccent.allCases {
                for background in [Color.paper, .surface, accent.surfaceColor, accent.washColor] {
                    XCTAssertGreaterThanOrEqual(contrast(accent.color, background, style: style), 4.5)
                }
                XCTAssertGreaterThanOrEqual(contrast(accent.onSolidColor, accent.solidColor, style: style), 4.5)
                XCTAssertGreaterThanOrEqual(contrast(.muted, accent.washColor, style: style), 4.5)
            }
        }
    }

    func testFavoritePersistsForAnUnfinishedCardWithoutChangingLoyalty() throws {
        let place = Place.samples[0]
        let before = try XCTUnwrap(store.membership(for: place))
        try store.setFavorite(true, for: place)
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertEqual(restored.membership(for: place)?.isFavorite, true)
        XCTAssertEqual(restored.membership(for: place)?.stamps, before.stamps)
        XCTAssertEqual(restored.membership(for: place)?.coupons, before.coupons)
        try store.setFavorite(false, for: place)
        XCTAssertEqual(store.membership(for: place), before)
    }

    func testOlderMembershipsDecodeWithoutResettingTheirPunches() throws {
        let data = Data(
            """
            [{"id":"monorail-pike","stamps":3,"archived":false,"events":[],"coupons":[]}]
            """.utf8)
        defaults.set(data, forKey: key)
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertNil(restored.storageError)
        XCTAssertEqual(restored.memberships.first?.stamps, 3)
        XCTAssertEqual(restored.memberships.first?.isFavorite, false)
    }

    func testGroupsPersistRenameAndAllowOneCardInMultipleGroups() throws {
        let id = Place.samples[0].id
        let first = try store.saveGroup(name: " Weekends ", placeIDs: [id])
        _ = try store.saveGroup(name: "Coffee", placeIDs: [id, Place.samples[1].id])
        let renamed = try store.saveGroup(id: first.id, name: "Saturday", placeIDs: first.placeIDs)
        XCTAssertEqual(renamed.id, first.id)
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertNil(restored.storageError)
        XCTAssertEqual(restored.groups, store.groups)
        XCTAssertEqual(restored.places(in: renamed), [Place.samples[0]])
        try store.deleteGroup(renamed)
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.membership(for: Place.samples[0])?.stamps, 5)
        XCTAssertEqual(store.redemptions.count, 3)
    }

    func testInvalidGroupsDoNotMutateSavedGroups() throws {
        _ = try store.saveGroup(name: "Coffee", placeIDs: [])
        let before = store.groups
        for name in [" ", String(repeating: "x", count: 41), "COFFEE", " coffee "] {
            XCTAssertThrowsError(try store.saveGroup(name: name, placeIDs: []))
        }
        XCTAssertThrowsError(try store.saveGroup(name: "Unknown", placeIDs: ["unknown"]))
        XCTAssertThrowsError(
            try store.saveGroup(
                name: "Duplicate",
                placeIDs: [
                    Place.samples[0].id, Place.samples[0].id,
                ]))
        XCTAssertThrowsError(try store.saveGroup(id: UUID(), name: "Gone", placeIDs: []))
        XCTAssertEqual(store.groups, before)
    }

    func testArchivePreservesFavoritesAndGroupsWhileHidingArchivedCards() throws {
        let place = Place.samples[0]
        try store.setFavorite(true, for: place)
        let group = try store.saveGroup(name: "Coffee", placeIDs: [place.id])
        store.setArchived(true, for: place)
        XCTAssertTrue(store.places(in: group).isEmpty)
        store.join(place)
        XCTAssertEqual(store.places(in: group), [place])
        XCTAssertEqual(store.membership(for: place)?.isFavorite, true)
        store.deleteLocalCards()
        XCTAssertTrue(LoyaltyStore(defaults: defaults).groups.isEmpty)
        store.resetDemo()
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertFalse(store.memberships.contains(where: \.isFavorite))
    }

    func testCorruptGroupDataIsReportedAndNotOverwritten() {
        let data = Data("invalid".utf8)
        defaults.set(data, forKey: "joeyy.groups.v1")
        let restored = LoyaltyStore(defaults: defaults)
        XCTAssertNotNil(restored.storageError)
        XCTAssertEqual(restored.memberships, store.memberships)
        XCTAssertEqual(defaults.data(forKey: "joeyy.groups.v1"), data)
    }

    func testPublishedThemeIsValidatedAndSurvivesRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let branding = MerchantBrandingStore(defaults: defaults, directory: directory)
        let place = Place.samples[0]
        var theme = MerchantTheme.sample(for: place.cardStyle)
        theme.coverURL = URL(string: "https://images.example.com/merchant/cover-v2.jpg")
        theme.typeface = .serif
        theme.allowsMotion = false
        let data = try JSONEncoder().encode(PublishedMerchantBranding(merchantID: place.id, theme: theme))
        try branding.applyPublishedBranding(data)
        XCTAssertEqual(branding.theme(for: place), theme)
        let restored = MerchantBrandingStore(defaults: defaults, directory: directory)
        XCTAssertEqual(restored.theme(for: place), theme)
        XCTAssertEqual(restored.coverURL(for: place), theme.coverURL)
        XCTAssertEqual(store.membership(for: place)?.stamps, 5)
    }

    func testInvalidThemeCannotReplaceAValidTheme() throws {
        let branding = MerchantBrandingStore(defaults: defaults, directory: .temporaryDirectory)
        let place = Place.samples[0]
        let original = branding.theme(for: place)
        var theme = original
        for url in [
            "http://example.com/image.jpg", "file:///tmp/image.jpg", "https://user:password@example.com/image.jpg",
        ] {
            theme.coverURL = URL(string: url)
            XCTAssertThrowsError(
                try branding.applyPublishedBranding(
                    JSONEncoder().encode(
                        PublishedMerchantBranding(merchantID: place.id, theme: theme)
                    )))
        }
        theme = original
        theme.lightInk = theme.lightPaper
        XCTAssertThrowsError(try theme.validate())
        theme = original
        theme.darkInk = 0xFFFFFFFF
        XCTAssertThrowsError(try theme.validate())
        XCTAssertThrowsError(
            try branding.applyPublishedBranding(
                JSONEncoder().encode(
                    PublishedMerchantBranding(merchantID: "unknown", theme: original)
                )))
        XCTAssertEqual(branding.theme(for: place), original)
        XCTAssertThrowsError(try ArtworkLoader.prepare(Data("not an image".utf8)))
    }

    func testLocalPhotoPreviewPersistsAndRemovalRestoresPublishedImage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let branding = MerchantBrandingStore(defaults: defaults, directory: directory)
        let place = Place.samples[0]
        let remote = try XCTUnwrap(URL(string: "https://images.example.com/cover.jpg"))
        try branding.previewRemoteCover(remote, for: place)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30))
        let png = try XCTUnwrap(
            renderer.image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
            }.pngData())
        try await branding.savePreview(png, for: place)
        XCTAssertTrue(branding.hasLocalPreview(for: place))
        let restored = MerchantBrandingStore(defaults: defaults, directory: directory)
        let url = try XCTUnwrap(restored.coverURL(for: place))
        XCTAssertTrue(url.isFileURL)
        XCTAssertNotNil(UIImage(data: try Data(contentsOf: url)))
        try restored.removeLocalPreview(for: place)
        XCTAssertEqual(restored.coverURL(for: place), remote)
        try restored.clear()
        XCTAssertNil(restored.coverURL(for: place))
    }
    private func contrast(_ first: Color, _ second: Color, style: UIUserInterfaceStyle) -> Double {
        func luminance(_ color: Color) -> Double {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            let channels = [red, green, blue].map { channel in
                let value = Double(channel)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
