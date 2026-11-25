//
//  EchoTheme.swift
//  Echo Launcher
//
//  Colours, type and small building blocks shared by the Echo screens, matching the PC launcher.
//

import SwiftUI

enum EchoTheme {
    static let yellow = Color(red: 0.96, green: 0.95, blue: 0.23)
    static let accent = Color(red: 0.66, green: 0.61, blue: 0.96)
    static let owned = Color(red: 0.25, green: 0.82, blue: 0.62)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.10)
    static let rail = Color.black.opacity(0.35)
    static let dim = Color.white.opacity(0.62)

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

struct EchoBackground: View {
    var tint: Color

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.04, blue: 0.10)
            LinearGradient(colors: [tint.opacity(0.55), Color.clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            RadialGradient(colors: [EchoTheme.accent.opacity(0.22), Color.clear], center: .bottomTrailing, startRadius: 20, endRadius: 620)
            LinearGradient(colors: [Color.black.opacity(0.55), Color.clear], startPoint: .leading, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}

struct EchoPageHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(EchoTheme.heading(40))
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
            .font(EchoTheme.heading(20))
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
            .background(EchoTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(EchoTheme.cardStroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct EchoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoTheme.heading(26))
            .foregroundColor(.black)
            .padding(.horizontal, 34)
            .padding(.vertical, 12)
            .background(EchoTheme.yellow.opacity(configuration.isPressed ? 0.75 : 1))
    }
}

struct EchoPillPicker: View {
    var options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { selection = index }) {
                    Text(options[index])
                        .font(EchoTheme.label(13))
                        .foregroundColor(selection == index ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selection == index ? EchoTheme.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EchoTheme.card)
        .clipShape(Capsule())
    }
}

struct EchoEmptyState: View {
    var symbol: String
    var text: String

    var body: some View {
        EchoCard {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(EchoTheme.accent)
                Text(text)
                    .font(EchoTheme.label(14))
                    .foregroundColor(EchoTheme.dim)
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
