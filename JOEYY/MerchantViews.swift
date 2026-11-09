import PhotosUI
import SwiftUI

extension MerchantTheme {
    var paper: Color { .adaptive(light: lightPaper, dark: darkPaper) }
    var ink: Color { .adaptive(light: lightInk, dark: darkInk) }
    var fontDesign: Font.Design {
        switch typeface {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    var galleryHeight: CGFloat {
        switch artwork {
        case .rail: 180
        case .cloud: 210
        case .stone: 190
        }
    }
}

struct MerchantCover: View {
    let place: Place
    var canRetry = true
    var poster = false
    @Environment(MerchantBrandingStore.self) private var branding
    @State private var image: UIImage?
    @State private var failure: String?
    @State private var retry = 0

    private var theme: MerchantTheme { branding.theme(for: place) }
    private var source: String {
        "\(branding.coverURL(for: place)?.absoluteString ?? "")-\(branding.revision(for: place)?.uuidString ?? "")-\(retry)"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    if poster {
                        DiscoveryArtwork(theme: theme)
                    } else {
                        MerchantArtwork(theme: theme)
                        if Place.discoverable.contains(place) {
                            Text(place.initials)
                                .font(.system(
                                    size: min(geometry.size.width, geometry.size.height) * 0.46,
                                    weight: .medium
                                ))
                                .tracking(-4)
                                .foregroundStyle(theme.ink)
                        }
                    }
                    if branding.coverURL(for: place) != nil {
                        if failure != nil && !canRetry {
                            Text("Image unavailable")
                                .font(.caption)
                                .foregroundStyle(theme.ink)
                                .padding(8)
                                .background(theme.paper)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        } else if failure == nil {
                            ProgressView().tint(theme.ink)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
        .task(id: source) {
            image = nil
            failure = nil
            guard let url = branding.coverURL(for: place) else { return }
            do {
                let data = try await ArtworkLoader.shared.load(url)
                try Task.checkCancellation()
                guard let decoded = UIImage(data: data) else { throw BrandingError.invalidImage }
                image = decoded
            } catch is CancellationError {
                // A reused gallery cell no longer needs its previous image.
            } catch {
                guard !Task.isCancelled else { return }
                failure = error.localizedDescription
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let failure, canRetry {
                Button {
                    retry += 1
                } label: {
                    Text("Retry image").font(.caption).padding(10)
                }
                .foregroundStyle(theme.ink)
                .frame(minHeight: 44)
                .background(theme.paper, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHint(failure)
                .accessibilityIdentifier("cover.retry.\(place.id)")
                .padding(8)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct MerchantArtwork: View {
    let theme: MerchantTheme

    var body: some View {
        ZStack {
            theme.paper
            Canvas { context, size in
                switch theme.artwork {
                case .rail:
                    for index in 0..<7 {
                        var line = Path()
                        let x = CGFloat(index) * size.width / 5 - size.width / 4
                        line.move(to: CGPoint(x: x, y: 0))
                        line.addLine(to: CGPoint(x: x + size.width * 0.6, y: size.height))
                        context.stroke(line, with: .color(theme.ink.opacity(0.13)), lineWidth: 14)
                    }
                case .cloud:
                    for index in 0..<3 {
                        let diameter = size.width * 0.7
                        let rect = CGRect(
                            x: CGFloat(index) * size.width * 0.3 - diameter / 3,
                            y: size.height * (index.isMultiple(of: 2) ? 0.15 : 0.48),
                            width: diameter, height: diameter
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(theme.ink.opacity(0.09)))
                    }
                case .stone:
                    for index in 0..<5 {
                        let width = size.width / 4
                        let rect = CGRect(
                            x: CGFloat(index) * width * 0.83 - width / 3,
                            y: size.height * 0.15 + CGFloat(index % 2) * size.height * 0.2,
                            width: width, height: size.height * 0.85
                        )
                        context.stroke(
                            Path(roundedRect: rect, cornerRadius: width * 0.4),
                            with: .color(theme.ink.opacity(0.2)), lineWidth: 2
                        )
                    }
                }
            }
        }
    }
}

private struct DiscoveryArtwork: View {
    let theme: MerchantTheme

    var body: some View {
        LinearGradient(
            colors: [theme.paper, theme.paper.mix(with: theme.ink, by: 0.22)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Canvas { context, size in
                let scale = size.width / 320
                context.scaleBy(x: scale, y: scale)
                context.fill(
                    Path(ellipseIn: CGRect(x: -70, y: -90, width: 380, height: 380)),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.35), .clear]),
                        center: CGPoint(x: 90, y: 80), startRadius: 0, endRadius: 250
                    )
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: 30, y: 20, width: 270, height: 270)),
                    with: .color(theme.ink.opacity(0.16)), lineWidth: 1
                )
                switch theme.artwork {
                case .rail: drawBread(in: context)
                case .stone: drawBooks(in: context)
                case .cloud: drawCoffee(in: context)
                }
                for index in 0..<120 {
                    let x = CGFloat((index * 73) % 320)
                    let y = CGFloat((index * 97) % 420)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(theme.ink.opacity(0.12))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func drawBread(in context: GraphicsContext) {
        context.drawLayer { bread in
            bread.translateBy(x: 160, y: 150)
            bread.rotate(by: .degrees(-28))
            bread.translateBy(x: -160, y: -150)
            bread.addFilter(.shadow(color: .black.opacity(0.28), radius: 12, x: 8, y: 18))
            let loaf = Path(roundedRect: CGRect(x: 48, y: 70, width: 224, height: 150), cornerRadius: 75)
            bread.fill(loaf, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFE2A0), Color(hex: 0xD58B32), Color(hex: 0x8B421C)]),
                startPoint: CGPoint(x: 90, y: 70), endPoint: CGPoint(x: 230, y: 220)
            ))
            bread.stroke(loaf, with: .color(Color(hex: 0x75401E).opacity(0.35)), lineWidth: 1)
            for index in 0..<4 {
                let x = CGFloat(index) * 39 + 83
                var cut = Path()
                cut.move(to: CGPoint(x: x + 5, y: 101))
                cut.addQuadCurve(
                    to: CGPoint(x: x + 12, y: 183),
                    control: CGPoint(x: x - 15, y: 145)
                )
                bread.stroke(cut, with: .color(Color(hex: 0x9B5424)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                bread.stroke(cut, with: .color(Color(hex: 0xFFE5AD)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
        }
    }

    private func drawBooks(in context: GraphicsContext) {
        for index in (0..<3).reversed() {
            context.drawLayer { book in
                book.translateBy(x: 160, y: 150)
                book.rotate(by: .degrees(Double(index) * 15 - 18))
                book.translateBy(x: -160, y: -150)
                book.addFilter(.shadow(color: .black.opacity(0.25), radius: 7, x: 6, y: 12))
                let x = CGFloat(index) * 9 + 69
                let y = CGFloat(index) * 4 + 49
                book.fill(
                    Path(roundedRect: CGRect(x: x + 5, y: y + 10, width: 165, height: 202), cornerRadius: 5),
                    with: .color(Color(hex: 0xF5E9CD))
                )
                let cover = Path(roundedRect: CGRect(x: x, y: y, width: 166, height: 202), cornerRadius: 5)
                let color = [Color(hex: 0x375544), Color(hex: 0xC2704B), Color(hex: 0xDDBD68)][index]
                book.fill(cover, with: .linearGradient(
                    Gradient(colors: [color.mix(with: .white, by: 0.12), color]),
                    startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + 166, y: y + 202)
                ))
                book.fill(
                    Path(CGRect(x: x + 9, y: y, width: 5, height: 202)),
                    with: .color(.black.opacity(0.18))
                )
                book.stroke(
                    Path(CGRect(x: x + 31, y: y + 27, width: 108, height: 146)),
                    with: .color(Color(hex: 0xF5E9CD).opacity(0.65)), lineWidth: 1
                )
                book.stroke(
                    Path(ellipseIn: CGRect(x: x + 50, y: y + 58, width: 70, height: 84)),
                    with: .color(Color(hex: 0xF5E9CD)), lineWidth: 2
                )
            }
        }
    }

    private func drawCoffee(in context: GraphicsContext) {
        context.drawLayer { cup in
            cup.translateBy(x: 160, y: 150)
            cup.rotate(by: .degrees(-25))
            cup.translateBy(x: -160, y: -150)
            cup.addFilter(.shadow(color: .black.opacity(0.28), radius: 12, x: 8, y: 18))
            cup.stroke(
                Path(ellipseIn: CGRect(x: 226, y: 109, width: 50, height: 68)),
                with: .color(Color(hex: 0xF3EDE6)), lineWidth: 17
            )
            cup.fill(
                Path(ellipseIn: CGRect(x: 57, y: 47, width: 206, height: 206)),
                with: .linearGradient(
                    Gradient(colors: [.white, Color(hex: 0xC9BEB4)]),
                    startPoint: CGPoint(x: 70, y: 50), endPoint: CGPoint(x: 250, y: 250)
                )
            )
            cup.fill(
                Path(ellipseIn: CGRect(x: 76, y: 66, width: 168, height: 168)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xBF8149), Color(hex: 0x61331D)]),
                    center: CGPoint(x: 137, y: 118), startRadius: 12, endRadius: 120
                )
            )
            for index in 0..<7 {
                let y = CGFloat(index) * 14 + 91
                let halfWidth = CGFloat(7 - index) * 5 + 6
                var foam = Path()
                foam.move(to: CGPoint(x: 160, y: y + 15))
                foam.addQuadCurve(to: CGPoint(x: 160 - halfWidth, y: y), control: CGPoint(x: 160 - halfWidth, y: y + 18))
                foam.addQuadCurve(to: CGPoint(x: 160, y: y + 5), control: CGPoint(x: 160 - halfWidth, y: y - 10))
                foam.addQuadCurve(to: CGPoint(x: 160 + halfWidth, y: y), control: CGPoint(x: 160 + halfWidth, y: y - 10))
                foam.addQuadCurve(to: CGPoint(x: 160, y: y + 15), control: CGPoint(x: 160 + halfWidth, y: y + 18))
                cup.fill(foam, with: .color(Color(hex: 0xFFF0D6)))
            }
        }
    }
}

struct PlaceGalleryTile: View {
    let place: Place
    let stamps: Int
    @Environment(MerchantBrandingStore.self) private var branding

    var body: some View {
        let theme = branding.theme(for: place)
        VStack(alignment: .leading, spacing: 0) {
            MerchantCover(place: place, canRetry: false)
                .frame(height: theme.galleryHeight)
            VStack(alignment: .leading, spacing: 10) {
                Text(place.name)
                    .font(.system(.title2, design: theme.fontDesign).weight(.medium))
                Text(place.neighborhood)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.rewardDescription).font(.subheadline)
                    Text(stamps == place.requiredPunches ? "Full card" : "\(stamps) of \(place.requiredPunches) punches")
                        .font(.caption.monospacedDigit())
                }
                .accessibilityHidden(true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.ink)
            .background(theme.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.ink.opacity(0.18)))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.name), \(place.rewardDescription)")
        .accessibilityValue("\(stamps) of \(place.requiredPunches) punches")
    }
}

struct DiscoveryTile: View {
    let place: Place
    let isAdded: Bool
    @Environment(MerchantBrandingStore.self) private var branding
    @Environment(\.reduceCardMotion) private var reduceMotion

    var body: some View {
        let theme = branding.theme(for: place)
        let allowsMotion = !reduceMotion && theme.allowsMotion
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                MerchantCover(place: place, canRetry: false, poster: true)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(allowsMotion ? 1.12 : 1)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content.offset(x: allowsMotion ? phase.value * -24 : 0)
                    }
            }
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 235)
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.name).font(.title.weight(.semibold))
                    Text(place.neighborhood).font(.caption)
                    Text("\(place.requiredPunches) stamps / \(place.rewardDescription)")
                        .font(.subheadline)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.9)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 80)
                        Color.black.opacity(0.9)
                    }
                    .padding(.top, -80)
                }
            }
            if isAdded {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .padding(12)
                    .background(.black.opacity(0.8), in: Circle())
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .background(theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.14)))
        .shadow(color: theme.ink.opacity(0.2), radius: 14, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(allowsMotion ? 1 - abs(phase.value) * 0.06 : 1)
                .rotation3DEffect(
                    .degrees(allowsMotion ? phase.value * -8 : 0),
                    axis: (x: 0, y: 1, z: 0), perspective: 0.35
                )
                .offset(y: allowsMotion ? abs(phase.value) * 8 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.name), \(place.neighborhood)")
        .accessibilityValue("\(place.requiredPunches) stamps, \(place.rewardDescription)\(isAdded ? ", card added" : "")")
        .accessibilityHint("Opens the place and its demo card.")
    }
}

struct BrandingPreviewView: View {
    let place: Place
    @Environment(MerchantBrandingStore.self) private var branding
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var remoteURL = ""
    @State private var loading = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MerchantCover(place: place).frame(height: 200).listRowInsets(EdgeInsets())
                }
                Section {
                    PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                        Text("Choose cover photo")
                            .frame(minHeight: 44)
                    }
                    .disabled(loading)
                    .accessibilityIdentifier("branding.choosePhoto")
                    if loading { ProgressView("Preparing image...") }
                    if branding.hasLocalPreview(for: place) {
                        Button("Remove local photo", role: .destructive) {
                            do { try branding.removeLocalPreview(for: place) }
                            catch { failure = error.localizedDescription }
                        }
                    }
                } footer: {
                    Text("Local preview only. This photo stays on this device and is not uploaded.")
                }
                Section {
                    TextField("https://", text: $remoteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("branding.coverURL")
                    Button("Preview server image") {
                        do {
                            let value = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let url = URL(string: value) else { throw BrandingError.invalidURL }
                            try branding.previewRemoteCover(url, for: place)
                        } catch { failure = error.localizedDescription }
                    }
                    .accessibilityIdentifier("branding.applyURL")
                    Button("Use original artwork") {
                        do {
                            try branding.previewRemoteCover(nil, for: place)
                            remoteURL = ""
                        } catch { failure = error.localizedDescription }
                    }
                } header: {
                    Text("Published image URL")
                } footer: {
                    Text("The merchant app uploads to your server. Customers load the published HTTPS image; they never receive upload credentials.")
                }
            }
            .appNavigationTitle("Preview branding")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(loading)
                }
            }
            .onAppear { remoteURL = branding.theme(for: place).coverURL?.absoluteString ?? "" }
            .task(id: selection) {
                guard let selection else { return }
                loading = true
                defer { loading = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else {
                        throw BrandingError.invalidImage
                    }
                    try await branding.savePreview(data, for: place)
                } catch is CancellationError {
                    // Closing a picker leaves the previous cover unchanged.
                } catch { failure = error.localizedDescription }
            }
            .alert("Couldn't update artwork", isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button("OK") { failure = nil }
            } message: { Text(failure ?? "") }
        }
        .interactiveDismissDisabled(loading)
    }
}
