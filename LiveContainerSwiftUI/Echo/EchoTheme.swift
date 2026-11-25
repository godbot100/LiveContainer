//
//  EchoTheme.swift
//  Echo Launcher
//
//  The PC launcher's design language: Burbank titles, Poppins text, Material Symbols icons,
//  frosted surfaces over blurred key art, and one accent per theme.
//

import SwiftUI
import CoreText

struct EchoPalette {
    var name: String
    var base: (Double, Double, Double)
    var accentSource: (Double, Double, Double)?

    private static func rgb(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xff) / 255, Double((hex >> 8) & 0xff) / 255, Double(hex & 0xff) / 255)
    }

    init(_ name: String, _ base: UInt32, accent: UInt32? = nil) {
        self.name = name
        self.base = EchoPalette.rgb(base)
        self.accentSource = accent.map(EchoPalette.rgb)
    }

    /// The PC launcher's themes (themes.js), default Timeless.
    static let all: [EchoPalette] = [
        EchoPalette("Forest", 0x0d5826), EchoPalette("Dawn", 0xf9fe49), EchoPalette("Galaxy", 0x1f2050, accent: 0x3d3fc3),
        EchoPalette("Impact", 0x501f24, accent: 0xc33d4a), EchoPalette("Rift", 0x00eeff), EchoPalette("Dark", 0x7521c4),
        EchoPalette("Frozen", 0x3278b9), EchoPalette("Molten", 0xdd4d29), EchoPalette("Neo", 0xfb8fff), EchoPalette("Timeless", 0xaba4ff),
    ]

    static func named(_ name: String) -> EchoPalette {
        all.first { $0.name == name } ?? all[all.count - 1]
    }

    /// The accent is the base colour lifted to at least 60% saturation and 55% lightness.
    var accentRGB: (Double, Double, Double) {
        let (r, g, b) = accentSource ?? base
        let high = max(r, g, b), low = min(r, g, b)
        var hue = 0.0, saturation = 0.0
        let lightness = (high + low) / 2
        if high != low {
            let spread = high - low
            saturation = lightness > 0.5 ? spread / (2 - high - low) : spread / (high + low)
            if high == r { hue = (g - b) / spread + (g < b ? 6 : 0) } else if high == g { hue = (b - r) / spread + 2 } else { hue = (r - g) / spread + 4 }
            hue *= 60
        }
        let s = max(saturation, 0.60), l = max(lightness, 0.55)
        let a = s * min(l, 1 - l)
        func channel(_ n: Double) -> Double {
            let k = (n + hue / 30).truncatingRemainder(dividingBy: 12)
            return l - a * max(-1, min(k - 3, min(9 - k, 1)))
        }
        return (channel(0), channel(8), channel(4))
    }

    var accent: Color {
        let (r, g, b) = accentRGB
        return Color(red: r, green: g, blue: b)
    }

    var accentInk: Color {
        let (r, g, b) = accentRGB
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6 ? Color(red: 0.10, green: 0.09, blue: 0.18) : .white
    }

    /// The tint is the base colour mixed 45% into near-black.
    var tint: Color {
        Color(red: base.0 * 0.45 + 0.039 * 0.55, green: base.1 * 0.45 + 0.035 * 0.55, blue: base.2 * 0.45 + 0.078 * 0.55)
    }
}

enum EchoTheme {
    static let themeKey = "EchoThemeName"
    static var palette = EchoPalette.named(UserDefaults.standard.string(forKey: themeKey) ?? "")

    static var accent: Color { palette.accent }
    static var accentInk: Color { palette.accentInk }
    static var tint: Color { palette.tint }
    static let yellow = Color(red: 1.0, green: 0.965, blue: 0.0)
    static let ink = Color(red: 0.10, green: 0.09, blue: 0.18)
    static let owned = Color(red: 0.25, green: 0.82, blue: 0.62)
    static let red = Color(red: 0.93, green: 0.33, blue: 0.36)
    static let pink = Color(red: 0.98, green: 0.42, blue: 0.68)
    static let dim = Color.white.opacity(0.66)
    static let radius: CGFloat = 9
    static let radiusLarge: CGFloat = 12

    private static var fontsReady = false

    static func registerFonts() {
        guard !fontsReady else { return }
        fontsReady = true
        let files = [("EchoBurbankBig", "otf"), ("EchoBurbankSmallBlack", "otf"), ("EchoBurbankSmallBold", "ttf"), ("EchoPoppins400", "ttf"),
                     ("EchoPoppins500", "ttf"), ("EchoPoppins600", "ttf"), ("EchoPoppins700", "ttf"), ("EchoSymbols", "ttf")]
        for (name, kind) in files {
            if let url = Bundle.main.url(forResource: name, withExtension: kind) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    /// Burbank Big: the hero, page titles, PLAY.
    static func heading(_ size: CGFloat) -> Font {
        registerFonts()
        return .custom("BurbankBigRegular-Black", fixedSize: size)
    }

    /// Burbank Small Black: card titles.
    static func title(_ size: CGFloat) -> Font {
        registerFonts()
        return .custom("BurbankSmall-Black", fixedSize: size)
    }

    /// Burbank Small Bold: small uppercase labels.
    static func caps(_ size: CGFloat) -> Font {
        registerFonts()
        return .custom("BurbankSmall-Bold", fixedSize: size)
    }

    /// Poppins: subtitles and body text.
    static func label(_ size: CGFloat, weight: Int = 500) -> Font {
        registerFonts()
        let face = weight >= 700 ? "Poppins-Bold" : weight >= 600 ? "Poppins-SemiBold" : weight >= 500 ? "Poppins-Medium" : "Poppins-Regular"
        return .custom(face, fixedSize: size)
    }

    static func image(_ name: String, _ kind: String) -> UIImage? {
        Bundle.main.path(forResource: name, ofType: kind).flatMap { UIImage(contentsOfFile: $0) }
    }
}

/// The Material Symbols Rounded glyphs the PC launcher uses, filled, weight 500.
enum EchoIcon: UInt32 {
    case home = 0xe9b2, builds = 0xe9b0, store = 0xf1cc, servers = 0xe875, person = 0xf0d3, settings = 0xe8b8
    case news = 0xeb81, friends = 0xea21, music = 0xe405, play = 0xe037, pause = 0xe034, next = 0xe044, previous = 0xe045
    case back = 0xe5c4, forward = 0xe5cc, copy = 0xe14d, download = 0xf090, add = 0xe990, check = 0xf0be, signOut = 0xe9ba
    case refresh = 0xe5d5, palette = 0xe40a, game = 0xea28, star = 0xf09a, build = 0xf8cd, show = 0xe8f4, hide = 0xe8f5
    case close = 0xe5cd, lock = 0xe899, addFriend = 0xea4d, medal = 0xea3f, locker = 0xf19e, stats = 0xe26b
}

struct EchoGlyph: View {
    var icon: EchoIcon
    var size: CGFloat = 20

    var body: some View {
        let _ = EchoTheme.registerFonts()
        Text(UnicodeScalar(icon.rawValue).map { String(Character($0)) } ?? "")
            .font(.custom("MaterialSymbolsRounded-Regular", fixedSize: size))
            .frame(width: size, height: size)
    }
}

/// A frosted surface: the theme tint at 20% over a blur. No border, no shadow.
struct EchoSurface: ViewModifier {
    var radius: CGFloat = EchoTheme.radius

    func body(content: Content) -> some View {
        content
            .background(EchoTheme.tint.opacity(0.20))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func echoSurface(radius: CGFloat = EchoTheme.radius) -> some View {
        modifier(EchoSurface(radius: radius))
    }
}

/// Key art blurred 3 px with a left and bottom scrim, the same on every page.
struct EchoBackground: View {
    var art: String
    var remote: URL? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.039, green: 0.035, blue: 0.078)
                if let remote {
                    AsyncImage(url: remote) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: 3)
                } else if let image = EchoTheme.image(art, "jpg") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 3)
                }
                LinearGradient(colors: [Color.black.opacity(0.72), Color.black.opacity(0.10)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [Color.black.opacity(0.55), Color.clear], startPoint: .bottom, endPoint: .center)
            }
        }
        .ignoresSafeArea()
    }
}

struct EchoPageHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(EchoTheme.heading(44))
                .foregroundColor(.white)
            Text(subtitle)
                .font(EchoTheme.label(14))
                .foregroundColor(EchoTheme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EchoSectionTitle: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(EchoTheme.caps(17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EchoCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .echoSurface()
    }
}

/// PLAY: Burbank Big on the yellow bar.
struct EchoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoTheme.heading(28))
            .foregroundColor(EchoTheme.ink)
            .padding(.horizontal, 36)
            .padding(.vertical, 12)
            .background(EchoTheme.yellow)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// The one text button: a rounded square, solid accent, or ghost or danger.
struct EchoButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost, danger }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoTheme.label(14, weight: 600))
            .foregroundColor(kind == .primary ? EchoTheme.accentInk : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(kind == .primary ? EchoTheme.accent : kind == .danger ? EchoTheme.red : Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// A round icon-only button.
struct EchoIconButton: View {
    var icon: EchoIcon
    var size: CGFloat = 44
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            EchoGlyph(icon: icon, size: size * 0.5)
                .foregroundColor(active ? EchoTheme.accentInk : .white)
                .frame(width: size, height: size)
                .background(active ? EchoTheme.accent : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct EchoPillPicker: View {
    var options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { withAnimation(.easeOut(duration: 0.2)) { selection = index } }) {
                    Text(options[index])
                        .font(EchoTheme.label(13, weight: 600))
                        .foregroundColor(selection == index ? EchoTheme.accentInk : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selection == index ? EchoTheme.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .echoSurface(radius: 100)
    }
}

struct EchoTag: View {
    var text: String
    var badge = false

    var body: some View {
        Text(text)
            .font(EchoTheme.label(11, weight: 600))
            .foregroundColor(badge ? EchoTheme.accentInk : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(badge ? EchoTheme.accent : EchoTheme.tint.opacity(0.20))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

struct EchoEmptyState: View {
    var icon: EchoIcon
    var title: String
    var text: String

    var body: some View {
        VStack(spacing: 8) {
            EchoGlyph(icon: icon, size: 34).foregroundColor(EchoTheme.accent)
            Text(title.uppercased()).font(EchoTheme.title(18)).foregroundColor(.white)
            Text(text).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .echoSurface(radius: EchoTheme.radiusLarge)
    }
}

struct EchoStatTile: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(EchoTheme.heading(30)).foregroundColor(.white)
            Text(label).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .echoSurface()
    }
}

struct EchoRemoteImage: View {
    var url: URL?
    var icon: EchoIcon

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    EchoGlyph(icon: icon, size: 22).foregroundColor(EchoTheme.dim)
                }
            }
        }
    }
}

struct EchoHideTabBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
