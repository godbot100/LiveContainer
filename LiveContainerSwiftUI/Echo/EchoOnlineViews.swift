//
//  EchoOnlineViews.swift
//  Echo Launcher
//
//  The pages filled from the Echo server once signed in: news, servers, store and profile.
//

import SwiftUI

struct EchoSignInPrompt: View {
    @ObservedObject var account: EchoAccount
    var text: String

    var body: some View {
        EchoEmptyState(symbol: "person.crop.circle.badge.questionmark", text: text)
        Button(account.busy ? "SIGNING IN…" : "SIGN IN WITH DISCORD") {
            Task { await account.signIn() }
        }
        .buttonStyle(EchoPrimaryButtonStyle())
        .disabled(account.busy)
        EchoAccountNotices(account: account)
    }
}

struct EchoAccountNotices: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        if !account.banNotice.isEmpty {
            Text(account.banNotice).font(EchoTheme.label(13)).foregroundColor(.red)
        }
        if !account.status.isEmpty {
            Text(account.status).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
        }
    }
}

struct EchoRemoteImage: View {
    var url: URL?
    var symbol: String

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: symbol).foregroundColor(EchoTheme.dim)
                }
            }
        }
    }
}

struct EchoNewsStrip: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        if !account.signedIn {
            EchoEmptyState(symbol: "newspaper.fill", text: "Sign in to see news from the Echo team.")
        } else if account.news.isEmpty {
            EchoEmptyState(symbol: "newspaper.fill", text: "No news right now.")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(account.news) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            EchoRemoteImage(url: item.image, symbol: "newspaper.fill")
                                .frame(width: 220, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(item.title.uppercased())
                                .font(EchoTheme.heading(15))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text(item.body)
                                .font(EchoTheme.label(12))
                                .foregroundColor(EchoTheme.dim)
                                .lineLimit(3)
                        }
                        .frame(width: 220, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct EchoServersPage: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        EchoPageHeader(title: "Servers", subtitle: "Every match running on Echo right now, live.")
        if !account.signedIn {
            EchoSignInPrompt(account: account, text: "Sign in to see the live server list.")
        } else {
            EchoCard {
                HStack {
                    Text("\(account.playersInMatch) in match").font(EchoTheme.label(14)).foregroundColor(.white)
                    Spacer()
                    Text("\(account.playersInQueue) in queue").font(EchoTheme.label(14)).foregroundColor(EchoTheme.dim)
                }
            }
            if account.servers.isEmpty {
                EchoEmptyState(symbol: "server.rack", text: "No server is running right now.")
            }
            ForEach(account.servers) { server in
                EchoCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.playlist.uppercased()).font(EchoTheme.heading(17)).foregroundColor(.white)
                            Text([server.region, server.idle ? "idle" : server.status].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                        }
                        Spacer()
                        Label("\(server.players)", systemImage: "person.2.fill")
                            .font(EchoTheme.label(14))
                            .foregroundColor(server.idle ? EchoTheme.dim : EchoTheme.owned)
                    }
                }
            }
            Button("REFRESH") {
                Task { await account.refreshServers() }
            }
            .buttonStyle(EchoPrimaryButtonStyle())
            EchoAccountNotices(account: account)
        }
    }
}

struct EchoStorePage: View {
    @ObservedObject var account: EchoAccount

    private func grid(_ items: [EchoShopItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    EchoRemoteImage(url: item.icon, symbol: "bag.fill")
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(item.name.uppercased()).font(EchoTheme.heading(14)).foregroundColor(.white).lineLimit(1)
                    Text(item.price.map { "\($0) V-Bucks" } ?? item.rarity.capitalized)
                        .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                }
            }
        }
    }

    var body: some View {
        EchoPageHeader(title: "Store", subtitle: "Today's item shop. Items are bought in game.")
        if !account.signedIn {
            EchoSignInPrompt(account: account, text: "Sign in to see the item shop.")
        } else {
            if let vbucks = account.vbucks {
                EchoCard {
                    Text("\(vbucks) V-Bucks").font(EchoTheme.heading(18)).foregroundColor(.white)
                }
            }
            if account.shopFeatured.isEmpty && account.shopDaily.isEmpty {
                EchoEmptyState(symbol: "bag.fill", text: "The item shop is empty right now.")
            }
            if !account.shopFeatured.isEmpty {
                EchoSectionTitle(text: "Featured")
                grid(account.shopFeatured)
            }
            if !account.shopDaily.isEmpty {
                EchoSectionTitle(text: "Daily")
                grid(account.shopDaily)
            }
            EchoAccountNotices(account: account)
        }
    }
}

struct EchoProfilePage: View {
    @ObservedObject var account: EchoAccount
    @State private var showPassword = false

    private func copyRow(_ title: String, _ value: String, shown: String) -> some View {
        EchoCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                    Text(shown).font(EchoTheme.label(15)).foregroundColor(.white).lineLimit(1)
                }
                Spacer()
                Button(action: { UIPasteboard.general.string = value }) {
                    Image(systemName: "doc.on.doc.fill").foregroundColor(EchoTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var body: some View {
        EchoPageHeader(title: "Profile", subtitle: "Your Echo account.")
        if !account.signedIn {
            EchoSignInPrompt(account: account, text: "Sign in with the Discord account you use for Echo.")
        } else {
            EchoCard {
                HStack(spacing: 14) {
                    EchoRemoteImage(url: URL(string: account.avatar), symbol: "person.fill")
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.username.uppercased()).font(EchoTheme.heading(22)).foregroundColor(.white)
                        if let vbucks = account.vbucks {
                            Text("\(vbucks) V-Bucks").font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
                        }
                    }
                    Spacer()
                }
            }
            if !account.gameEmail.isEmpty {
                EchoSectionTitle(text: "Game sign-in")
                copyRow("Email", account.gameEmail, shown: account.gameEmail)
                copyRow("Password", account.gamePassword, shown: showPassword ? account.gamePassword : String(repeating: "•", count: 10))
                Button(showPassword ? "Hide password" : "Show password") {
                    showPassword.toggle()
                }
                .font(EchoTheme.label(13))
                .foregroundColor(EchoTheme.accent)
            }
            Button("SIGN OUT") {
                account.signOut()
            }
            .buttonStyle(EchoPrimaryButtonStyle())
            EchoAccountNotices(account: account)
        }
    }
}
