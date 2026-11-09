import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

struct MerchantTheme: Codable, Hashable, Sendable {
    enum Typeface: String, Codable, CaseIterable, Sendable {
        case standard, rounded, serif, monospaced
    }

    enum Artwork: String, Codable, Sendable {
        case rail, cloud, stone
    }

    var lightPaper: UInt32
    var lightInk: UInt32
    var darkPaper: UInt32
    var darkInk: UInt32
    var typeface: Typeface
    var artwork: Artwork
    var coverURL: URL?
    var allowsMotion: Bool

    func validate() throws {
        guard [lightPaper, lightInk, darkPaper, darkInk].allSatisfy({ $0 <= 0xFFFFFF }),
              Self.contrast(lightPaper, lightInk) >= 4.5,
              Self.contrast(darkPaper, darkInk) >= 4.5 else {
            throw BrandingError.contrast
        }
        if let coverURL { try Self.validateCoverURL(coverURL) }
    }

    static func validateCoverURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { throw BrandingError.invalidURL }
    }

    private static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            let channels = [16, 8, 0].map { shift -> Double in
                let component = Double((hex >> shift) & 255) / 255
                return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let values = [luminance(first), luminance(second)]
        return ((values.max() ?? 0) + 0.05) / ((values.min() ?? 0) + 0.05)
    }

    static func sample(for style: CardStyle) -> Self {
        switch style {
        case .rail:
            Self(lightPaper: 0xF5A174, lightInk: 0x351B13, darkPaper: 0x5C2C20,
                 darkInk: 0xFFE6D5, typeface: .monospaced, artwork: .rail, allowsMotion: true)
        case .cloud:
            Self(lightPaper: 0xDDE9F2, lightInk: 0x213849, darkPaper: 0x223844,
                 darkInk: 0xDCE8F2, typeface: .rounded, artwork: .cloud, allowsMotion: true)
        case .stone:
            Self(lightPaper: 0xE8DFC8, lightInk: 0x353E2D, darkPaper: 0x31382D,
                 darkInk: 0xF0E7D2, typeface: .serif, artwork: .stone, allowsMotion: true)
        }
    }

    static func sample(for place: Place) -> Self {
        var theme = sample(for: place.cardStyle)
        switch place.id {
        case "saint-bread":
            theme.lightPaper = 0xF2CB58
            theme.lightInk = 0x443015
            theme.darkPaper = 0x49391D
            theme.darkInk = 0xFFE6A5
            theme.typeface = .standard
        case "book-larder":
            theme.lightPaper = 0xCED9BA
            theme.lightInk = 0x283B2B
            theme.darkPaper = 0x293D30
            theme.darkInk = 0xE0EACF
            theme.typeface = .standard
        case "gloom-coffee":
            theme.lightPaper = 0xD6C9EC
            theme.lightInk = 0x342545
            theme.darkPaper = 0x392A49
            theme.darkInk = 0xEEDFFB
            theme.typeface = .standard
        default:
            break
        }
        return theme
    }
}

/// The merchant service publishes this after uploading artwork, never image bytes or upload credentials.
struct PublishedMerchantBranding: Codable, Sendable {
    let merchantID: String
    let theme: MerchantTheme
}

enum BrandingError: LocalizedError {
    case invalidURL, contrast, unknownMerchant, invalidImage, imageTooLarge, response(Int), unavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Use an HTTPS image URL without embedded credentials."
        case .contrast: "Merchant colors must provide at least 4.5:1 text contrast in light and dark mode."
        case .unknownMerchant: "This business could not be found."
        case .invalidImage: "This file could not be read as an image."
        case .imageTooLarge: "Choose an image smaller than 20 MB."
        case .response(let status): "The image server returned HTTP \(status)."
        case .unavailable: "The image server did not return an image."
        }
    }
}

@MainActor
@Observable
final class MerchantBrandingStore {
    private var themes: [String: MerchantTheme] = [:]
    private var previewRevisions: [String: UUID] = [:]
    private(set) var storageError: String?
    private let defaults: UserDefaults
    private let directory: URL
    private let key = "joeyy.merchant-themes.v1"

    init(defaults: UserDefaults = .standard, directory: URL) {
        self.defaults = defaults
        self.directory = directory
        if let data = defaults.data(forKey: key) {
            do {
                let saved = try JSONDecoder().decode([String: MerchantTheme].self, from: data)
                for (id, theme) in saved {
                    guard Place.catalog.contains(where: { $0.id == id }) else { throw BrandingError.unknownMerchant }
                    try theme.validate()
                }
                themes = saved
            } catch {
                storageError = "Saved merchant artwork settings could not be read: \(error.localizedDescription)"
            }
        }
    }

    func theme(for place: Place) -> MerchantTheme {
        themes[place.id] ?? .sample(for: place)
    }

    func coverURL(for place: Place) -> URL? {
        // Reading the revision also invalidates a cover when its local file changes.
        _ = previewRevisions[place.id]
        let local = directory.appendingPathComponent("\(place.id).jpg")
        if FileManager.default.fileExists(atPath: local.path) { return local }
        return theme(for: place).coverURL
    }

    func revision(for place: Place) -> UUID? { previewRevisions[place.id] }

    func hasLocalPreview(for place: Place) -> Bool {
        coverURL(for: place)?.isFileURL == true
    }

    func applyPublishedBranding(_ data: Data) throws {
        let published = try JSONDecoder().decode(PublishedMerchantBranding.self, from: data)
        guard Place.catalog.contains(where: { $0.id == published.merchantID }) else {
            throw BrandingError.unknownMerchant
        }
        try published.theme.validate()
        var updated = themes
        updated[published.merchantID] = published.theme
        defaults.set(try JSONEncoder().encode(updated), forKey: key)
        themes = updated
        storageError = nil
    }

    func previewRemoteCover(_ url: URL?, for place: Place) throws {
        var theme = theme(for: place)
        theme.coverURL = url
        try theme.validate()
        let data = try JSONEncoder().encode(PublishedMerchantBranding(
            merchantID: place.id, theme: theme
        ))
        try removeLocalPreview(for: place)
        try applyPublishedBranding(data)
    }

    func savePreview(_ data: Data, for place: Place) async throws {
        guard Place.catalog.contains(place) else { throw BrandingError.unknownMerchant }
        let prepared = try await Task.detached {
            try ArtworkLoader.prepare(data)
        }.value
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try prepared.write(to: directory.appendingPathComponent("\(place.id).jpg"), options: .atomic)
        previewRevisions[place.id] = UUID()
    }

    func removeLocalPreview(for place: Place) throws {
        let url = directory.appendingPathComponent("\(place.id).jpg")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        previewRevisions[place.id] = UUID()
    }

    func clear() throws {
        for place in Place.catalog { try removeLocalPreview(for: place) }
        themes = [:]
        defaults.removeObject(forKey: key)
        storageError = nil
    }
}

actor ArtworkLoader {
    static let shared = ArtworkLoader()
    private let cache = NSCache<NSURL, NSData>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 24
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func load(_ url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        try MerchantTheme.validateCoverURL(url)
        if let saved = cache.object(forKey: url as NSURL) { return saved as Data }
        let (bytes, response) = try await session.bytes(for: URLRequest(
            url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20
        ))
        guard let response = response as? HTTPURLResponse else { throw BrandingError.unavailable }
        guard response.statusCode == 200 else { throw BrandingError.response(response.statusCode) }
        guard response.mimeType?.hasPrefix("image/") == true else { throw BrandingError.unavailable }
        guard response.expectedContentLength <= 20 * 1_024 * 1_024 else { throw BrandingError.imageTooLarge }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > 20 * 1_024 * 1_024 { throw BrandingError.imageTooLarge }
        }
        try Task.checkCancellation()
        let prepared = try Self.prepare(data)
        cache.setObject(prepared as NSData, forKey: url as NSURL, cost: prepared.count)
        return prepared
    }

    nonisolated static func prepare(_ data: Data) throws -> Data {
        guard data.count <= 20 * 1_024 * 1_024 else { throw BrandingError.imageTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw BrandingError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw BrandingError.invalidImage }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw BrandingError.invalidImage }
        return output as Data
    }
}
