import Foundation
import Observation
import UIKit

/// Business-side data, stored on this device as JSON. Operations are shaped like the planned
/// merchant service (get/save business, get/publish program, dashboard) so a server can replace it.
@MainActor
@Observable
final class PartnerStore {
    /// Placeholder owner identity; there is no business sign-in yet.
    nonisolated static let localOwnerSubject = "local-device-owner"

    private(set) var state: PartnerData
    private(set) var storageError: String?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let now: () -> Date

    init(fileURL: URL, reset: Bool = false, now: @escaping () -> Date = { .now }) {
        self.fileURL = fileURL
        self.now = now
        if reset {
            try? FileManager.default.removeItem(at: fileURL)
            state = .empty
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            state = .empty
            return
        }
        do {
            state = try JSONDecoder().decode(PartnerData.self, from: Data(contentsOf: fileURL))
        } catch {
            state = .empty
            storageError = "Saved data couldn't be read (\(error.localizedDescription)). Load the sample or set up your business to start again."
        }
    }

    static func fileURL(testing: Bool) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(testing ? "business-ui-tests.json" : "business-data.json")
    }

    // MARK: Business profile

    var business: Business? { state.business }

    @discardableResult
    func saveBusiness(name: String, location: String, logoPNG: Data?) throws -> Business {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PartnerError.missingName }
        guard name.count <= Business.nameLimit else { throw PartnerError.nameTooLong }
        guard location.count <= Business.locationLimit else { throw PartnerError.locationTooLong }

        let business: Business
        if var existing = state.business {
            existing.name = name
            existing.location = location
            existing.logoPNG = logoPNG
            business = existing
        } else {
            business = Business(
                id: UUID(), ownerSubject: Self.localOwnerSubject, name: name,
                location: location, logoPNG: logoPNG, currentProgramVersionID: nil
            )
        }
        var next = state
        next.business = business
        try persist(next)
        return business
    }

    // MARK: Program versions

    var currentProgram: ProgramVersion? {
        guard let id = state.business?.currentProgramVersionID else { return nil }
        return state.versions.first { $0.id == id }
    }

    var versionsNewestFirst: [ProgramVersion] {
        guard let businessID = state.business?.id else { return [] }
        return state.versions.filter { $0.businessID == businessID }.sorted { $0.version > $1.version }
    }

    var nextVersionNumber: Int { (versionsNewestFirst.first?.version ?? 0) + 1 }

    func usage(of version: ProgramVersion) -> VersionUsage {
        var inProgress = 0
        var completed = 0
        for card in state.cards where card.programVersionID == version.id {
            if card.status == .completed { completed += 1 } else { inProgress += 1 }
        }
        let status: VersionUsage.Status = version.id == currentProgram?.id
            ? .live
            : (inProgress > 0 ? .finishing : .retired)
        return VersionUsage(status: status, inProgress: inProgress, completed: completed)
    }

    /// In-progress cards issued under versions that are no longer live.
    var cardsFinishingOlderVersions: Int {
        guard let business = state.business else { return 0 }
        return state.cards.filter {
            $0.businessID == business.id && $0.status == .active
                && $0.programVersionID != business.currentProgramVersionID
        }.count
    }

    /// What publishing a new version would do to cards that aren't complete yet.
    func publishImpact() -> (keepRules: Int, switchToNew: Int) {
        guard let businessID = state.business?.id else { return (0, 0) }
        var keep = 0
        var move = 0
        for card in state.cards where card.businessID == businessID && card.status == .active {
            if card.punches == 0 { move += 1 } else { keep += 1 }
        }
        return (keep, move)
    }

    /// Publishes a new immutable version. Cards with punches keep their version until complete;
    /// cards with no punches yet switch to the new version, since no progress is lost.
    @discardableResult
    func publish(_ draft: ProgramDraft) throws -> ProgramVersion {
        guard var business = state.business else { throw PartnerError.missingBusiness }
        let settings = try draft.validated()
        if let currentProgram, settings.matches(currentProgram) { throw PartnerError.unchangedProgram }

        let version = ProgramVersion(
            id: UUID(), businessID: business.id, version: nextVersionNumber,
            requiredPunches: settings.requiredPunches, rewardDescription: settings.rewardDescription,
            design: settings.design, publishedAt: now()
        )
        business.currentProgramVersionID = version.id
        var next = state
        next.versions.append(version)
        next.business = business
        for index in next.cards.indices
        where next.cards[index].businessID == business.id
            && next.cards[index].status == .active && next.cards[index].punches == 0 {
            next.cards[index].programVersionID = version.id
        }
        try persist(next)
        return version
    }

    // MARK: Dashboard

    func summary(for period: ReportPeriod) -> DashboardSummary {
        let end = now()
        return summary(from: period.start(now: end), to: end)
    }

    /// Counts activity where `from <= timestamp < to`. Enrollment is always lifetime.
    func summary(from start: Date?, to end: Date) -> DashboardSummary {
        guard let businessID = state.business?.id else { return .zero }
        func inRange(_ date: Date) -> Bool {
            (start.map { date >= $0 } ?? true) && date < end
        }
        let cards = state.cards.filter { $0.businessID == businessID }
        let rewards = state.rewards.filter { $0.businessID == businessID }
        return DashboardSummary(
            enrolledCardholders: Set(cards.map(\.customerID)).count,
            punches: state.punches.filter { $0.businessID == businessID && inRange($0.occurredAt) }.count,
            rewardsEarned: rewards.filter { inRange($0.earnedAt) }.count,
            rewardsRedeemed: rewards.filter { $0.redeemedAt.map(inRange) ?? false }.count
        )
    }

    // MARK: Prototype data

    func loadNoremaSample() {
        let logo = UIImage(named: "NoremaLogo")?.pngData()
        do {
            try persist(SampleData.norema(now: now(), logoPNG: logo))
        } catch {
            storageError = error.localizedDescription
        }
    }

    func startOver() {
        do {
            try persist(.empty)
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func persist(_ next: PartnerData) throws {
        do {
            let encoded = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            throw PartnerError.storage(error.localizedDescription)
        }
        state = next
        storageError = nil
    }
}

enum LogoProcessor {
    /// Downscales a picked image to a square-friendly PNG no larger than `maxDimension` points.
    static func normalizedPNG(from data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
