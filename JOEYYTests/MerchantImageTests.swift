import UIKit
import XCTest

@testable import JOEYY

@MainActor
final class MerchantImageTests: XCTestCase {
    private func loader() -> ArtworkLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageResponseProtocol.self]
        return ArtworkLoader(session: URLSession(configuration: configuration))
    }

    func testPublishedImageLoadsAndIsCachedWithoutLoyaltyCredentials() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40))
        let png = try XCTUnwrap(
            renderer.image { context in
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
            }.pngData())
        ImageResponseProtocol.response.set(status: 200, headers: ["Content-Type": "image/png"], data: png)
        let loader = loader()
        let url = try XCTUnwrap(URL(string: "https://images.example.com/cover.jpg"))
        let first = try await loader.load(url)
        XCTAssertNotNil(UIImage(data: first))
        ImageResponseProtocol.response.set(status: 404, headers: [:], data: Data())
        let cached = try await loader.load(url)
        XCTAssertEqual(first, cached)
        XCTAssertNil(ImageResponseProtocol.response.request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(ImageResponseProtocol.response.request?.httpBody)
    }

    func testRemoteImageFailuresAreNotSuccessShapedFallbacks() async throws {
        let url = try XCTUnwrap(URL(string: "https://images.example.com/missing.jpg"))
        for (status, headers, body) in [
            (404, ["Content-Type": "image/jpeg"], Data()),
            (200, ["Content-Type": "text/html"], Data("<html></html>".utf8)),
            (200, ["Content-Type": "image/png"], Data("not PNG".utf8)),
            (200, ["Content-Type": "image/jpeg", "Content-Length": "30000000"], Data()),
        ] {
            ImageResponseProtocol.response.set(status: status, headers: headers, data: body)
            do {
                _ = try await loader().load(url)
                XCTFail("An invalid server image must fail explicitly.")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }
    }

    func testLocalPreparationDownsamplesLargeCovers() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 20), format: format)
        let image = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3200, height: 20))
        }
        let data = try ArtworkLoader.prepare(XCTUnwrap(image.pngData()))
        let result = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(result.width, 1600)
        XCTAssertEqual(result.height, 10)
    }

    func testCancelledPhotoPreparationDoesNotWriteAPreview() async throws {
        let suite = "JOEYY-photo-cancellation-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite) }
        let branding = MerchantBrandingStore(defaults: defaults, directory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        let data = try XCTUnwrap(image.pngData())
        let task = Task { try await branding.savePreview(data, for: Place.samples[0]) }
        task.cancel()
        do {
            try await task.value
            XCTFail("Cancelled preparation must not save a new cover.")
        } catch is CancellationError {
            XCTAssertFalse(branding.hasLocalPreview(for: Place.samples[0]))
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }
}

private final class ImageResponse: @unchecked Sendable {
    private let lock = NSLock()
    private var status = 200
    private var headers: [String: String] = [:]
    private var data = Data()
    private var lastRequest: URLRequest?

    var request: URLRequest? { lock.withLock { lastRequest } }

    func set(status: Int, headers: [String: String], data: Data) {
        lock.withLock {
            self.status = status
            self.headers = headers
            self.data = data
        }
    }

    func snapshot(for request: URLRequest) -> (Int, [String: String], Data) {
        lock.withLock {
            lastRequest = request
            return (status, headers, data)
        }
    }
}

private final class ImageResponseProtocol: URLProtocol, @unchecked Sendable {
    static let response = ImageResponse()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, headers, data) = Self.response.snapshot(for: request)
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
