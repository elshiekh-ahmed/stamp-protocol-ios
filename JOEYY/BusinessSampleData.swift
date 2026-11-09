import Foundation

/// Deterministic, fictional Norema Cafe activity for demos and tests.
enum SampleData {
    static let noremaBusinessID = UUID(uuidString: "6E0B1A52-4C1E-4E57-9D7A-2B1D5C0A0101")!
    static let noremaVersionID = UUID(uuidString: "6E0B1A52-4C1E-4E57-9D7A-2B1D5C0A0201")!
    static let customerCount = 140

    static func norema(now: Date, logoPNG: Data?) -> PartnerData {
        var rng = SeededGenerator(seed: 0x4E4F_5245_4D41)
        let day: TimeInterval = 86_400
        let version = ProgramVersion(
            id: noremaVersionID, businessID: noremaBusinessID, version: 1,
            requiredPunches: 10, rewardDescription: "One handcrafted drink",
            design: CardDesign(
                theme: MerchantTheme(
                    lightPaper: 0xF7EFD9, lightInk: 0x2F241E, darkPaper: 0x2F241E, darkInk: 0xF7EFD9,
                    typeface: .serif, artwork: .cloud, allowsMotion: true
                ),
                coverJPEG: nil
            ),
            publishedAt: now.addingTimeInterval(-150 * day)
        )
        let business = Business(
            id: noremaBusinessID, ownerSubject: PartnerStore.localOwnerSubject, name: "Norema Cafe",
            location: "Capitol Hill, Seattle, WA, United States", logoPNG: logoPNG, currentProgramVersionID: version.id
        )

        var cards: [LoyaltyCard] = []
        var punches: [PunchEvent] = []
        var rewards: [Reward] = []

        func newCard(for customer: UUID, at date: Date) -> LoyaltyCard {
            LoyaltyCard(
                id: .random(using: &rng), businessID: noremaBusinessID, customerID: customer,
                programVersionID: version.id, punches: 0, status: .active, createdAt: date
            )
        }

        for _ in 0..<customerCount {
            let customer = UUID.random(using: &rng)
            let joinedDaysAgo = Double(Int.random(in: 1...140, using: &rng))
            var time = now.addingTimeInterval(-joinedDaysAgo * day + Double.random(in: 0..<36_000, using: &rng))
            let visitLimit = Int.random(in: 1...36, using: &rng)
            let gaps = Int.random(in: 1...5, using: &rng)...Int.random(in: 6...16, using: &rng)
            var card = newCard(for: customer, at: time)
            var visits = 0

            while time < now && visits < visitLimit {
                card.punches += 1
                visits += 1
                punches.append(PunchEvent(
                    id: .random(using: &rng), businessID: noremaBusinessID, cardID: card.id,
                    eventID: "nfc-" + UUID.random(using: &rng).uuidString.lowercased(), occurredAt: time
                ))
                if card.punches == version.requiredPunches {
                    card.status = .completed
                    cards.append(card)
                    let redeemedAt = time.addingTimeInterval(Double.random(in: 0.2...12, using: &rng) * day)
                    let redeemed = redeemedAt < now && Double.random(in: 0..<1, using: &rng) < 0.85
                    rewards.append(Reward(
                        id: .random(using: &rng), businessID: noremaBusinessID, cardID: card.id,
                        earnedAt: time, redeemedAt: redeemed ? redeemedAt : nil
                    ))
                    card = newCard(for: customer, at: time)
                }
                time = time.addingTimeInterval(
                    Double(Int.random(in: gaps, using: &rng)) * day + Double.random(in: -7_200...7_200, using: &rng)
                )
            }
            cards.append(card)
        }

        return PartnerData(
            business: business, versions: [version], cards: cards,
            punches: punches.sorted { $0.occurredAt < $1.occurredAt }, rewards: rewards
        )
    }
}

/// SplitMix64: a small, fast, reproducible generator so sample data is identical on every device.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension UUID {
    static func random<G: RandomNumberGenerator>(using generator: inout G) -> UUID {
        let words = (generator.next(), generator.next())
        return withUnsafeBytes(of: words) { UUID(uuid: $0.load(as: uuid_t.self)) }
    }
}
