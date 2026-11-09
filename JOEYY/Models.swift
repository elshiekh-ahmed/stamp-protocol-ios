import Foundation
import Observation

struct Place: Identifiable, Hashable {
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
    let id: String
    let clientID: String
    let name: String
    let neighborhood: String
    let address: String
    let requiredPunches: Int
    let rewardDescription: String
    let website: String
    let cardStyle: CardStyle

    static let punchRange = 3...12

    static let samples: [Place] = [
        Place(
            id: "monorail-pike", clientID: "6A2E3D81-7B49-4F12-A0C3-819D62E00101",
            name: "Monorail Espresso", neighborhood: "Seattle / Pike St",
            address: "510 Pike St, Seattle",
            requiredPunches: 8, rewardDescription: "Espresso",
            website: "https://monorailespresso.com/pages/pike-st", cardStyle: .rail
        ),
        Place(
            id: "cloud-city", clientID: "7B3F4E92-8C50-4023-B1D4-92AE73F00202",
            name: "Cloud City Coffee", neighborhood: "Seattle / Maple Leaf",
            address: "8801 Roosevelt Way NE, Seattle",
            requiredPunches: 6, rewardDescription: "Brewed coffee",
            website: "https://www.cloudcitycoffee.com/pages/where-to-find-cloud-city", cardStyle: .cloud
        ),
        Place(
            id: "five-stones-kirkland", clientID: "8C405FA3-9D61-4134-82E5-A3BF84000303",
            name: "5 Stones Coffee Co", neighborhood: "Kirkland / Central Way",
            address: "312 Central Way, Kirkland",
            requiredPunches: 10, rewardDescription: "Latte",
            website: "https://5stonescoffeeco.com/pages/kirkland", cardStyle: .stone
        )
    ]

    static let discoverable: [Place] = [
        Place(
            id: "saint-bread", clientID: "9D516AB4-AE72-4245-93F6-B4C095000404",
            name: "Saint Bread", neighborhood: "Seattle / Portage Bay",
            address: "1421 NE Boat St, Seattle",
            requiredPunches: 8, rewardDescription: "Pastry",
            website: "https://www.saintbread.com", cardStyle: .rail
        ),
        Place(
            id: "book-larder", clientID: "AE627BC5-BF83-4356-A407-C5D1A6000505",
            name: "Book Larder", neighborhood: "Seattle / Fremont",
            address: "4252 Fremont Ave N, Seattle",
            requiredPunches: 6, rewardDescription: "10% off one book",
            website: "https://booklarder.com", cardStyle: .stone
        ),
        Place(
            id: "gloom-coffee", clientID: "BF738CD6-C094-4467-B518-D6E2B7000606",
            name: "Gloom Coffee", neighborhood: "Seattle / Pioneer Square",
            address: "240 2nd Ave S, Seattle",
            requiredPunches: 8, rewardDescription: "Espresso",
            website: "https://gloom.coffee", cardStyle: .cloud
        )
    ]

    static let catalog = samples + discoverable

    static func search(_ query: String) -> [Place] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        if let identifier = UUID(uuidString: value) {
            return catalog.filter { UUID(uuidString: $0.clientID) == identifier }
        }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(value) }
    }
}

enum CardStyle: CaseIterable {
    case rail, cloud, stone
}

struct VisitEvent: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case joined, stamp, reward
    }

    var id = UUID()
    let kind: Kind
    let date: Date
    let rewardTitle: String?
    let stampCost: Int?

    init(kind: Kind, date: Date, rewardTitle: String? = nil, stampCost: Int? = nil) {
        self.kind = kind
        self.date = date
        self.rewardTitle = rewardTitle
        self.stampCost = stampCost
    }
}

struct Membership: Identifiable, Codable, Equatable {
    var id: String
    var stamps: Int
    var archived = false
    var events: [VisitEvent]
    var coupons: [Coupon] = []
    var isFavorite = false
}

extension Membership {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            stamps: try values.decode(Int.self, forKey: .stamps),
            archived: try values.decode(Bool.self, forKey: .archived),
            events: try values.decode([VisitEvent].self, forKey: .events),
            coupons: try values.decodeIfPresent([Coupon].self, forKey: .coupons) ?? [],
            isFavorite: try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        )
    }
}

struct PlaceGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var placeIDs: [String]
}

struct LoyaltyExport: Codable {
    let memberships: [Membership]
    let groups: [PlaceGroup]
}

struct Coupon: Identifiable, Codable, Hashable {
    let id: UUID
    var usedAt: Date?
}

struct Redemption: Identifiable, Hashable {
    let place: Place
    let event: VisitEvent
    let coupon: Coupon?

    var id: UUID { event.id }
    var isAvailable: Bool { coupon.map { $0.usedAt == nil } ?? false }
}

enum DemoError: LocalizedError {
    case notJoined, insufficientStamps, unknownProgram, cardComplete, archivedCard
    case couponNotFound, couponAlreadyUsed
    case invalidGroupName, duplicateGroupName, invalidGroup

    var errorDescription: String? {
        switch self {
        case .notJoined: "Join this card first."
        case .insufficientStamps: "Fill this card before claiming the reward."
        case .unknownProgram: "This program could not be found."
        case .cardComplete: "This card is full. Claim the reward before collecting again."
        case .archivedCard: "Restore this card before collecting stamps or claiming a reward."
        case .couponNotFound: "This coupon could not be found."
        case .couponAlreadyUsed: "This coupon has already been used."
        case .invalidGroupName: "Use a group name between 1 and 40 characters."
        case .duplicateGroupName: "A group with this name already exists."
        case .invalidGroup: "This group or one of its cards could not be found."
        }
    }
}

@MainActor
@Observable
final class LoyaltyStore {
    private(set) var memberships: [Membership] = []
    private(set) var groups: [PlaceGroup] = []
    private(set) var storageError: String?
    private let defaults: UserDefaults
    private let key = "joeyy.memberships.v2"
    private let groupsKey = "joeyy.groups.v1"

    init(defaults: UserDefaults = .standard, reset: Bool = false) {
        self.defaults = defaults
        if reset {
            resetDemo()
        } else if let data = defaults.data(forKey: key) {
            do {
                let saved = try JSONDecoder().decode([Membership].self, from: data)
                let couponIDs = saved.flatMap { $0.coupons.map(\.id) }
                let redemptionIDs = saved.flatMap { $0.events.filter { $0.kind == .reward }.map(\.id) }
                guard Set(saved.map(\.id)).count == saved.count,
                      Set(couponIDs).count == couponIDs.count,
                      Set(redemptionIDs).count == redemptionIDs.count,
                      saved.allSatisfy({ member in
                          Place.catalog.contains {
                              $0.id == member.id && (0...$0.requiredPunches).contains(member.stamps)
                          } &&
                          Set(member.coupons.map(\.id)).count == member.coupons.count &&
                          member.coupons.allSatisfy { coupon in
                              member.events.filter { $0.id == coupon.id }.count == 1 &&
                              member.events.contains { event in
                                  event.id == coupon.id && event.kind == .reward &&
                                  event.rewardTitle?.isEmpty == false &&
                                  (event.stampCost ?? 0) > 0 &&
                                  (coupon.usedAt.map { $0 >= event.date } ?? true)
                              }
                          }
                      }) else {
                    storageError = "Saved cards could not be read."
                    return
                }
                memberships = saved
            } catch {
                storageError = "Saved cards could not be read: \(error.localizedDescription)"
            }
        } else {
            // The new programs have new identities; old demo balances must not be reassigned.
            resetDemo()
        }
        if let data = defaults.data(forKey: groupsKey) {
            do {
                let saved = try JSONDecoder().decode([PlaceGroup].self, from: data)
                guard Set(saved.map(\.id)).count == saved.count,
                      Set(saved.map { $0.name.lowercased() }).count == saved.count,
                      saved.allSatisfy({ group in
                          !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          group.name.count <= 40 &&
                          Set(group.placeIDs).count == group.placeIDs.count &&
                          group.placeIDs.allSatisfy { id in memberships.contains { $0.id == id } }
                      }) else { throw DemoError.invalidGroup }
                groups = saved
            } catch {
                storageError = "Saved groups could not be read: \(error.localizedDescription)"
            }
        }
    }

    var activePlaces: [Place] {
        memberships.filter { !$0.archived }.compactMap { member in
            Place.catalog.first { $0.id == member.id }
        }
    }

    var redemptions: [Redemption] {
        memberships.flatMap { member -> [Redemption] in
            guard let place = Place.catalog.first(where: { $0.id == member.id }) else { return [] }
            return member.events.filter { $0.kind == .reward }.map { event in
                Redemption(place: place, event: event, coupon: member.coupons.first { $0.id == event.id })
            }
        }
        .sorted { $0.event.date > $1.event.date }
    }

    func membership(for place: Place) -> Membership? {
        memberships.first { $0.id == place.id }
    }

    func setFavorite(_ favorite: Bool, for place: Place) throws {
        guard let index = memberships.firstIndex(where: { $0.id == place.id }) else {
            throw DemoError.notJoined
        }
        memberships[index].isFavorite = favorite
        save()
    }

    func places(in group: PlaceGroup) -> [Place] {
        activePlaces.filter { group.placeIDs.contains($0.id) }
    }

    @discardableResult
    func saveGroup(id: UUID? = nil, name: String, placeIDs: [String]) throws -> PlaceGroup {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { throw DemoError.invalidGroupName }
        guard !groups.contains(where: {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) else { throw DemoError.duplicateGroupName }
        guard Set(placeIDs).count == placeIDs.count,
              placeIDs.allSatisfy({ id in memberships.contains { $0.id == id } }),
              id == nil || groups.contains(where: { $0.id == id }) else {
            throw DemoError.invalidGroup
        }
        let group = PlaceGroup(id: id ?? UUID(), name: name, placeIDs: placeIDs)
        var updated = groups.filter { $0.id != group.id }
        updated.append(group)
        updated.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        defaults.set(try JSONEncoder().encode(updated), forKey: groupsKey)
        groups = updated
        return group
    }

    func deleteGroup(_ group: PlaceGroup) throws {
        guard groups.contains(where: { $0.id == group.id }) else { throw DemoError.invalidGroup }
        let updated = groups.filter { $0.id != group.id }
        defaults.set(try JSONEncoder().encode(updated), forKey: groupsKey)
        groups = updated
    }

    func join(_ place: Place) {
        if let index = memberships.firstIndex(where: { $0.id == place.id }) {
            memberships[index].archived = false
        } else {
            memberships.insert(
                Membership(id: place.id, stamps: 0, events: [
                    VisitEvent(kind: .joined, date: .now)
                ]),
                at: 0
            )
        }
        save()
    }

    func addStamp(to place: Place) throws {
        guard Place.catalog.contains(place) else { throw DemoError.unknownProgram }
        guard let index = memberships.firstIndex(where: { $0.id == place.id }) else {
            throw DemoError.notJoined
        }
        guard !memberships[index].archived else { throw DemoError.archivedCard }
        guard memberships[index].stamps < place.requiredPunches else { throw DemoError.cardComplete }
        memberships[index].stamps += 1
        memberships[index].events.insert(VisitEvent(kind: .stamp, date: .now), at: 0)
        save()
    }

    @discardableResult
    func claimReward(at place: Place) throws -> Coupon {
        guard Place.catalog.contains(place) else { throw DemoError.unknownProgram }
        guard let index = memberships.firstIndex(where: { $0.id == place.id }) else {
            throw DemoError.notJoined
        }
        guard !memberships[index].archived else { throw DemoError.archivedCard }
        guard memberships[index].stamps == place.requiredPunches else { throw DemoError.insufficientStamps }
        let event = VisitEvent(
            kind: .reward, date: .now,
            rewardTitle: place.rewardDescription, stampCost: place.requiredPunches
        )
        let coupon = Coupon(id: event.id)
        memberships[index].stamps = 0
        memberships[index].events.insert(event, at: 0)
        memberships[index].coupons.insert(coupon, at: 0)
        save()
        return coupon
    }

    func useCoupon(_ id: UUID) throws {
        guard let memberIndex = memberships.firstIndex(where: { member in
            member.coupons.contains { $0.id == id }
        }), let couponIndex = memberships[memberIndex].coupons.firstIndex(where: { $0.id == id }) else {
            throw DemoError.couponNotFound
        }
        guard memberships[memberIndex].coupons[couponIndex].usedAt == nil else {
            throw DemoError.couponAlreadyUsed
        }
        memberships[memberIndex].coupons[couponIndex].usedAt = .now
        save()
    }

    func setArchived(_ archived: Bool, for place: Place) {
        guard let index = memberships.firstIndex(where: { $0.id == place.id }) else { return }
        memberships[index].archived = archived
        save()
    }

    func resetDemo() {
        groups = []
        defaults.removeObject(forKey: groupsKey)
        let calendar = Calendar.current
        memberships = zip(Place.samples, [5, 6, 2]).map { place, count in
            let events = (0..<count).map { day in
                VisitEvent(
                    kind: .stamp,
                    date: calendar.date(byAdding: .day, value: -day - 1, to: .now) ?? .now
                )
            }
            return Membership(
                id: place.id, stamps: count,
                events: events + [VisitEvent(
                    kind: .joined,
                    date: calendar.date(byAdding: .day, value: -20, to: .now) ?? .now
                )]
            )
        }
        seedDemoCoupons()
        save()
        if storageError == nil {
            defaults.removeObject(forKey: "joeyy.memberships.v1")
            defaults.removeObject(forKey: "joeyy.coupon-samples.v1")
        }
    }

    func deleteLocalCards() {
        memberships = []
        groups = []
        defaults.removeObject(forKey: groupsKey)
        save()
    }

    private func seedDemoCoupons() {
        for (offset, place) in Place.samples.enumerated() {
            guard let index = memberships.firstIndex(where: { $0.id == place.id }) else { continue }
            let date = Calendar.current.date(byAdding: .day, value: -9 - offset, to: .now) ?? .now
            let event = VisitEvent(
                kind: .reward, date: date,
                rewardTitle: place.rewardDescription, stampCost: place.requiredPunches
            )
            memberships[index].coupons.append(Coupon(id: event.id))
            memberships[index].events.append(event)
            memberships[index].events.sort { $0.date > $1.date }
        }
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(memberships), forKey: key)
            storageError = nil
        } catch {
            storageError = "Your changes could not be saved: \(error.localizedDescription)."
        }
    }
}
