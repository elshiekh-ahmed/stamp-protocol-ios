import Foundation

// Business-side (merchant) models. These mirror the planned partner API tables
// (Business, ProgramVersion, Card, PunchEvent, Reward). Card appearance uses the same
// MerchantTheme the customer app renders, and the punch target uses Place.punchRange.

struct Business: Codable, Equatable, Sendable {
    static let nameLimit = 40
    static let locationLimit = 120

    let id: UUID
    /// The signed-in owner's identity-provider user ID. This prototype uses a device placeholder.
    let ownerSubject: String
    var name: String
    /// A place chosen from Apple Maps suggestions: a city, street address, or map listing.
    var location: String
    var logoPNG: Data?
    var currentProgramVersionID: UUID?
}

/// Contrast-safe light and dark card colors. Every preset passes MerchantTheme's 4.5:1 check.
struct CardPalette: Identifiable, Hashable, Sendable {
    let name: String
    let lightPaper: UInt32
    let lightInk: UInt32
    let darkPaper: UInt32
    let darkInk: UInt32

    var id: String { name }

    static let all: [CardPalette] = [
        CardPalette(name: "Cream", lightPaper: 0xF7EFD9, lightInk: 0x2F241E, darkPaper: 0x2F241E, darkInk: 0xF7EFD9),
        CardPalette(name: "Apricot", lightPaper: 0xF5A174, lightInk: 0x351B13, darkPaper: 0x5C2C20, darkInk: 0xFFE6D5),
        CardPalette(name: "Sky", lightPaper: 0xDDE9F2, lightInk: 0x213849, darkPaper: 0x223844, darkInk: 0xDCE8F2),
        CardPalette(name: "Sand", lightPaper: 0xE8DFC8, lightInk: 0x353E2D, darkPaper: 0x31382D, darkInk: 0xF0E7D2),
        CardPalette(name: "Honey", lightPaper: 0xF2CB58, lightInk: 0x443015, darkPaper: 0x49391D, darkInk: 0xFFE6A5),
        CardPalette(name: "Sage", lightPaper: 0xCED9BA, lightInk: 0x283B2B, darkPaper: 0x293D30, darkInk: 0xE0EACF),
        CardPalette(name: "Lilac", lightPaper: 0xD6C9EC, lightInk: 0x342545, darkPaper: 0x392A49, darkInk: 0xEEDFFB),
    ]

    func matches(_ theme: MerchantTheme) -> Bool {
        theme.lightPaper == lightPaper && theme.lightInk == lightInk
            && theme.darkPaper == darkPaper && theme.darkInk == darkInk
    }

    func apply(to theme: inout MerchantTheme) {
        theme.lightPaper = lightPaper
        theme.lightInk = lightInk
        theme.darkPaper = darkPaper
        theme.darkInk = darkInk
    }
}

extension MerchantTheme.Artwork: CaseIterable {
    static var allCases: [Self] { [.rail, .cloud, .stone] }

    /// The card stock each artwork style uses on the customer's punch card.
    var stockName: String {
        switch self {
        case .rail: "Clipped"
        case .cloud: "Rounded"
        case .stone: "Square"
        }
    }

    var cardStyle: CardStyle {
        switch self {
        case .rail: .rail
        case .cloud: .cloud
        case .stone: .stone
        }
    }
}

extension MerchantTheme.Typeface {
    var title: String {
        switch self {
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Mono"
        }
    }
}

/// How the business's card looks to customers.
struct CardDesign: Codable, Equatable, Sendable {
    /// Colors, typeface, card stock, and motion, exactly as the customer app renders them.
    /// `coverURL` stays empty in this prototype; the cover photo is kept locally instead.
    var theme: MerchantTheme
    /// Optional cover photo (JPEG, at most 1600 px), shown instead of the generated artwork.
    var coverJPEG: Data?

    static let starter = CardDesign(
        theme: MerchantTheme(
            lightPaper: 0xF7EFD9, lightInk: 0x2F241E, darkPaper: 0x2F241E, darkInk: 0xF7EFD9,
            typeface: .serif, artwork: .cloud, allowsMotion: true
        ),
        coverJPEG: nil
    )
}

/// A published, immutable set of loyalty rules and card appearance.
struct ProgramVersion: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let businessID: UUID
    let version: Int
    let requiredPunches: Int
    let rewardDescription: String
    let design: CardDesign
    let publishedAt: Date
}

/// Editable, unpublished program settings.
struct ProgramDraft: Equatable, Sendable {
    /// Same 3–12 target the customer app uses for every card.
    static let punchRange = Place.punchRange
    static let rewardLimit = 60

    var requiredPunches: Int
    var rewardDescription: String
    var design: CardDesign

    static let starter = ProgramDraft(requiredPunches: 10, rewardDescription: "", design: .starter)

    init(requiredPunches: Int, rewardDescription: String, design: CardDesign) {
        self.requiredPunches = requiredPunches
        self.rewardDescription = rewardDescription
        self.design = design
    }

    init(version: ProgramVersion) {
        self.init(
            requiredPunches: version.requiredPunches,
            rewardDescription: version.rewardDescription,
            design: version.design
        )
    }

    /// Returns trimmed settings, or throws the first validation problem.
    func validated() throws -> ProgramDraft {
        var result = self
        result.rewardDescription = rewardDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.punchRange.contains(requiredPunches) else { throw PartnerError.invalidPunches }
        guard !result.rewardDescription.isEmpty else { throw PartnerError.missingReward }
        guard result.rewardDescription.count <= Self.rewardLimit else { throw PartnerError.rewardTooLong }
        do { try design.theme.validate() } catch { throw PartnerError.invalidTheme }
        return result
    }

    func matches(_ version: ProgramVersion) -> Bool {
        var trimmed = self
        trimmed.rewardDescription = rewardDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == ProgramDraft(version: version)
    }
}

enum CardStatus: String, Codable, Sendable {
    case active, completed
}

/// One customer's punch card. Once it has a punch, it keeps the rules of its version until complete.
struct LoyaltyCard: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let businessID: UUID
    let customerID: UUID
    /// Reassigned to a newly published version only while the card has no punches.
    var programVersionID: UUID
    var punches: Int
    var status: CardStatus
    let createdAt: Date
}

struct PunchEvent: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let businessID: UUID
    let cardID: UUID
    /// The validated external (NFC) event identifier, used to deduplicate retries.
    let eventID: String
    let occurredAt: Date
}

struct Reward: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let businessID: UUID
    let cardID: UUID
    let earnedAt: Date
    var redeemedAt: Date?
}

struct PartnerData: Codable, Equatable, Sendable {
    var business: Business?
    var versions: [ProgramVersion]
    var cards: [LoyaltyCard]
    var punches: [PunchEvent]
    var rewards: [Reward]

    static let empty = PartnerData(business: nil, versions: [], cards: [], punches: [], rewards: [])
}

enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case all = "All"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .quarter: "Last 90 days"
        case .all: "All time"
        }
    }

    /// The inclusive start of the period, or `nil` for all time.
    func start(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .today: calendar.startOfDay(for: now)
        case .week: calendar.date(byAdding: .day, value: -7, to: now)
        case .month: calendar.date(byAdding: .day, value: -30, to: now)
        case .quarter: calendar.date(byAdding: .day, value: -90, to: now)
        case .all: nil
        }
    }
}

/// How a published version is being used by customers' cards.
struct VersionUsage: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        /// New cards are issued under this version.
        case live
        /// No longer issued, but customers are still completing cards under it.
        case finishing
        /// No longer issued and no cards are still in progress.
        case retired
    }

    var status: Status
    /// Cards not yet complete, including fresh cards with no punches.
    var inProgress: Int
    var completed: Int
}

struct DashboardSummary: Equatable, Sendable {
    /// Lifetime unique customers holding any card from this business.
    var enrolledCardholders: Int
    var punches: Int
    var rewardsEarned: Int
    var rewardsRedeemed: Int

    static let zero = DashboardSummary(enrolledCardholders: 0, punches: 0, rewardsEarned: 0, rewardsRedeemed: 0)
}

enum PartnerError: LocalizedError, Equatable {
    case missingBusiness, missingName, nameTooLong, locationTooLong, invalidLogo
    case invalidPunches, missingReward, rewardTooLong, invalidTheme, unchangedProgram
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .missingBusiness: "Set up your business first."
        case .missingName: "Enter your business name."
        case .nameTooLong: "Use \(Business.nameLimit) characters or fewer for the business name."
        case .locationTooLong: "Use \(Business.locationLimit) characters or fewer for the location."
        case .invalidLogo: "That image couldn't be used as a logo. Choose a different photo."
        case .invalidPunches: "Choose between \(ProgramDraft.punchRange.lowerBound) and \(ProgramDraft.punchRange.upperBound) punches."
        case .missingReward: "Describe the reward customers earn."
        case .rewardTooLong: "Use \(ProgramDraft.rewardLimit) characters or fewer for the reward."
        case .invalidTheme: "Card colors must provide at least 4.5:1 text contrast in light and dark mode."
        case .unchangedProgram: "This matches the published card. Make a change before publishing."
        case .storage(let message): "Couldn't save on this device: \(message)"
        }
    }
}

extension Place {
    /// A stand-in Place so the business preview renders with the customer app's own card views.
    static func businessPreview(
        business: Business?, requiredPunches: Int, reward: String, artwork: MerchantTheme.Artwork
    ) -> Place {
        Place(
            id: "business-preview", clientID: business?.id.uuidString ?? "",
            name: business?.name ?? "Your business", neighborhood: business?.location ?? "",
            address: business?.location ?? "",
            requiredPunches: min(max(requiredPunches, Place.punchRange.lowerBound), Place.punchRange.upperBound),
            rewardDescription: reward.isEmpty ? "Your reward" : reward,
            website: "", cardStyle: artwork.cardStyle
        )
    }
}
