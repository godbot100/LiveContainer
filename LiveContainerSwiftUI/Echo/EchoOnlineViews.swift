//
//  EchoOnlineViews.swift
//  Echo Launcher
//
//  The pages filled from the Echo server once signed in, laid out like the PC launcher's:
//  news cards and article, match cards, item shop, profile with stats and locker, friends.
//

import SwiftUI

struct EchoAccountNotices: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        if !account.banNotice.isEmpty {
            Text(account.banNotice).font(EchoTheme.label(13)).foregroundColor(EchoTheme.red)
        }
        if !account.status.isEmpty {
            Text(account.status).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
        }
    }
}

struct EchoSignInPrompt: View {
    @ObservedObject var account: EchoAccount
    var text: String

    var body: some View {
        EchoEmptyState(icon: .person, title: "Sign in", text: text)
        Button(account.busy ? "Signing in…" : "Sign in with Discord") {
            Task { await account.signIn() }
        }
        .buttonStyle(EchoButtonStyle())
        .disabled(account.busy)
        EchoAccountNotices(account: account)
    }
}

/// A picture card with the title over a bottom fade, a frosted pill top-right and a summary underneath.
struct EchoFeatureCard<Trailing: View>: View {
    var image: URL?
    var icon: EchoIcon
    var title: String
    var summary: String
    var pill: String
    var ratio: CGFloat
    var trailing: Trailing

    init(image: URL?, icon: EchoIcon, title: String, summary: String, pill: String, ratio: CGFloat = 1.6, @ViewBuilder trailing: () -> Trailing) {
        self.image = image
        self.icon = icon
        self.title = title
        self.summary = summary
        self.pill = pill
        self.ratio = ratio
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(ratio, contentMode: .fit)
                .overlay(EchoRemoteImage(url: image, icon: icon))
                .overlay(LinearGradient(colors: [Color.black.opacity(0.78), Color.clear], startPoint: .bottom, endPoint: .center))
                .overlay(alignment: .topTrailing) {
                    if !pill.isEmpty {
                        EchoTag(text: pill).padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom) {
                        Text(title.uppercased())
                            .font(EchoTheme.title(18))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        trailing
                    }
                    .padding(12)
                }
                .clipped()
            if !summary.isEmpty {
                Text(summary)
                    .font(EchoTheme.label(12))
                    .foregroundColor(EchoTheme.dim)
                    .lineLimit(2)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .echoSurface(radius: EchoTheme.radiusLarge)
    }
}

extension EchoFeatureCard where Trailing == EmptyView {
    init(image: URL?, icon: EchoIcon, title: String, summary: String, pill: String, ratio: CGFloat = 1.6) {
        self.init(image: image, icon: icon, title: title, summary: summary, pill: pill, ratio: ratio) { EmptyView() }
    }
}

/// Home's news column: the pinned or newest post wide, then the next two side by side.
struct EchoHomeNews: View {
    @ObservedObject var account: EchoAccount
    var open: (EchoNewsItem) -> Void

    private var posts: [EchoNewsItem] {
        let pinned = account.news.filter { $0.pinned }
        return Array((pinned + account.news.filter { !$0.pinned }).prefix(3))
    }

    private func card(_ item: EchoNewsItem, ratio: CGFloat) -> some View {
        Button(action: { open(item) }) {
            EchoFeatureCard(image: item.image, icon: .news, title: item.title, summary: item.body, pill: item.date, ratio: ratio)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EchoSectionTitle(text: "News")
            if !account.signedIn {
                EchoEmptyState(icon: .news, title: "News", text: "Sign in to see news from the Echo team.")
            } else if posts.isEmpty {
                EchoEmptyState(icon: .news, title: "No news", text: "Nothing has been posted yet.")
            } else {
                card(posts[0], ratio: 1.8)
                if posts.count > 1 {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(posts.dropFirst()) { card($0, ratio: 1.33) }
                    }
                }
            }
        }
    }
}

struct EchoArticlePage: View {
    @ObservedObject var account: EchoAccount
    var item: EchoNewsItem
    var open: (EchoNewsItem) -> Void
    var close: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text(item.title.uppercased()).font(EchoTheme.heading(40)).foregroundColor(.white)
            Spacer()
            Button(action: close) {
                Label { Text("Home") } icon: { EchoGlyph(icon: .back, size: 16) }
                    .font(EchoTheme.label(13, weight: 600))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .echoSurface(radius: 100)
            }
            .buttonStyle(.plain)
        }
        HStack(spacing: 6) {
            if item.pinned { EchoTag(text: "Pinned", badge: true) }
            if !item.date.isEmpty { EchoTag(text: item.date) }
        }
        Text(item.body)
            .font(EchoTheme.label(15, weight: 400))
            .foregroundColor(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .echoSurface(radius: EchoTheme.radiusLarge)
        let others = account.news.filter { $0.id != item.id }.prefix(3)
        if !others.isEmpty {
            EchoSectionTitle(text: "More news")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(Array(others)) { other in
                    Button(action: { open(other) }) {
                        EchoFeatureCard(image: other.image, icon: .news, title: other.title, summary: "", pill: other.date)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EchoServersPage: View {
    @ObservedObject var account: EchoAccount
    var openStore: () -> Void

    private func regionColor(_ region: String) -> Color {
        region.uppercased().hasPrefix("NA") ? EchoTheme.owned : EchoTheme.accent
    }

    private func summary(_ server: EchoServerRow) -> String {
        var parts: [String] = []
        if let started = server.startedAt {
            parts.append("\(max(0, Int(Date().timeIntervalSince(started) / 60)))m in")
        }
        if server.bots > 0 { parts.append("\(server.bots) bots") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        EchoPageHeader(title: "Servers", subtitle: "Every match running on Echo right now, live.")
        if !account.signedIn {
            EchoSignInPrompt(account: account, text: "Sign in to see the live server list.")
        } else {
            let live = account.servers.filter { !$0.idle }
            let ready = account.servers.filter { $0.idle }.count
            if live.isEmpty {
                EchoEmptyState(icon: .servers, title: "No matches", text: "No match is running right now.")
            } else {
                HStack(spacing: 10) {
                    EchoStatTile(value: "\(live.reduce(0) { $0 + $1.players + $1.bots })", label: "Players in matches")
                    EchoStatTile(value: "\(ready)", label: "Servers ready")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                    ForEach(live) { server in
                        EchoFeatureCard(image: server.image, icon: .servers, title: server.playlist, summary: summary(server),
                                        pill: server.status == "starting" ? "Starting" : server.status == "ending" ? "Ending" : "") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(server.alive ?? server.players) LEFT").font(EchoTheme.heading(24)).foregroundColor(.white)
                                if !server.region.isEmpty {
                                    Text(server.region.uppercased())
                                        .font(EchoTheme.label(11, weight: 700))
                                        .foregroundColor(EchoTheme.ink)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(regionColor(server.region))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            Button(action: openStore) {
                HStack {
                    Text("WANT MORE SERVERS? HELP ECHO OUT!").font(EchoTheme.title(18)).foregroundColor(EchoTheme.ink)
                    Spacer()
                    EchoGlyph(icon: .forward, size: 22).foregroundColor(EchoTheme.ink)
                }
                .padding(16)
                .background(EchoTheme.pink)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusLarge, style: .continuous))
            }
            .buttonStyle(.plain)
            EchoAccountNotices(account: account)
        }
    }
}

struct EchoItemGrid: View {
    var items: [EchoShopItem]

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "legendary": return Color(red: 0.92, green: 0.55, blue: 0.18)
        case "epic": return Color(red: 0.62, green: 0.30, blue: 0.86)
        case "rare": return Color(red: 0.20, green: 0.55, blue: 0.95)
        case "uncommon": return Color(red: 0.35, green: 0.72, blue: 0.20)
        default: return Color(red: 0.50, green: 0.53, blue: 0.58)
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .background(LinearGradient(colors: [rarityColor(item.rarity), rarityColor(item.rarity).opacity(0.35)], startPoint: .top, endPoint: .bottom))
                        .overlay(EchoRemoteImage(url: item.icon, icon: .locker))
                        .clipped()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name.uppercased()).font(EchoTheme.caps(13)).foregroundColor(.white).lineLimit(1)
                        Text(item.price.map { "\($0) V-Bucks" } ?? item.rarity.capitalized)
                            .font(EchoTheme.label(11)).foregroundColor(EchoTheme.dim)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .echoSurface()
            }
        }
    }
}

struct EchoStorePage: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        EchoPageHeader(title: "Store", subtitle: "Today's item shop. Items are bought in game.")
        if !account.signedIn {
            EchoSignInPrompt(account: account, text: "Sign in to see the item shop.")
        } else {
            if let vbucks = account.vbucks {
                EchoStatTile(value: "\(vbucks)", label: "V-Bucks")
            }
            if account.shopFeatured.isEmpty && account.shopDaily.isEmpty {
                EchoEmptyState(icon: .store, title: "Shop closed", text: "The item shop is empty right now.")
            }
            if !account.shopFeatured.isEmpty {
                EchoSectionTitle(text: "Featured")
                EchoItemGrid(items: account.shopFeatured)
            }
            if !account.shopDaily.isEmpty {
                EchoSectionTitle(text: "Daily")
                EchoItemGrid(items: account.shopDaily)
            }
            EchoAccountNotices(account: account)
        }
    }
}

/// A player's profile: skin, name and level, then Stats or Locker.
struct EchoProfileBody: View {
    var profile: EchoProfile
    @State private var tab = 0

    var body: some View {
        HStack(spacing: 14) {
            EchoRemoteImage(url: profile.skin, icon: .person)
                .frame(width: 84, height: 84)
                .background(EchoTheme.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusLarge, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username.uppercased()).font(EchoTheme.heading(34)).foregroundColor(.white).lineLimit(1)
                HStack(spacing: 6) {
                    if let level = profile.level { EchoTag(text: "Level \(level)", badge: true) }
                    if let tier = profile.tier { EchoTag(text: "Tier \(tier)") }
                    EchoTag(text: "\(profile.friendCount) friends")
                }
            }
            Spacer()
        }
        EchoPillPicker(options: ["Stats", "Locker"], selection: $tab)
        if tab == 0 {
            if profile.stats.isEmpty {
                EchoEmptyState(icon: .stats, title: "No stats", text: "No matches recorded this season, or stats are hidden.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(profile.stats) { stat in
                        EchoStatTile(value: stat.value, label: stat.label)
                    }
                }
            }
        } else {
            if profile.locker.isEmpty {
                EchoEmptyState(icon: .locker, title: "Empty locker", text: "Nothing to show, or the locker is hidden.")
            }
            ForEach(profile.locker) { section in
                EchoSectionTitle(text: "\(section.label) · \(section.items.count)")
                EchoItemGrid(items: section.items)
            }
        }
    }
}

struct EchoProfilePage: View {
    @ObservedObject var account: EchoAccount

    var body: some View {
        if !account.signedIn {
            EchoPageHeader(title: "Profile", subtitle: "Stats and locker.")
            EchoSignInPrompt(account: account, text: "Sign in with the Discord account you use for Echo.")
        } else if let profile = account.ownProfile {
            EchoProfileBody(profile: profile)
            EchoAccountNotices(account: account)
        } else {
            EchoPageHeader(title: account.username.isEmpty ? "Profile" : account.username, subtitle: "Stats and locker.")
            EchoEmptyState(icon: .person, title: "Profile", text: "Your profile could not be loaded yet.")
            Button("Try again") {
                Task { await account.refreshAll() }
            }
            .buttonStyle(EchoButtonStyle())
            EchoAccountNotices(account: account)
        }
    }
}

/// The pill in the top-right corner: how many friends are online. Opens the friends list.
struct EchoFriendsPill: View {
    @ObservedObject var account: EchoAccount
    @State private var open = false

    var body: some View {
        Button(action: {
            open = true
            Task { await account.refreshFriends() }
        }) {
            HStack(spacing: 6) {
                EchoGlyph(icon: .friends, size: 18)
                Text("\(account.friends.filter { $0.online }.count)").font(EchoTheme.label(13, weight: 600))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .echoSurface(radius: 100)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) {
            EchoFriendsSheet(account: account)
        }
    }
}

struct EchoFriendsSheet: View {
    @ObservedObject var account: EchoAccount
    @State private var shown: EchoProfile?
    @State private var loading = ""

    private func statusText(_ status: String) -> String {
        switch status {
        case "online": return "In game"
        case "launcher": return "In the launcher"
        default: return "Offline"
        }
    }

    var body: some View {
        ZStack {
            EchoTheme.tint.opacity(0.55).background(Color.black).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let shown {
                        Button(action: { self.shown = nil }) {
                            Label { Text("Friends") } icon: { EchoGlyph(icon: .back, size: 16) }
                        }
                        .buttonStyle(EchoButtonStyle(kind: .ghost))
                        EchoProfileBody(profile: shown)
                    } else {
                        Text("FRIENDS").font(EchoTheme.heading(36)).foregroundColor(.white)
                        if account.friends.isEmpty {
                            EchoEmptyState(icon: .friends, title: "No friends yet", text: "Friends you add in game appear here.")
                        }
                        ForEach(account.friends) { friend in
                            Button(action: {
                                loading = friend.id
                                Task {
                                    shown = await account.profile(of: friend.id)
                                    loading = ""
                                }
                            }) {
                                HStack(spacing: 12) {
                                    EchoRemoteImage(url: friend.skin, icon: .person)
                                        .frame(width: 42, height: 42)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(friend.online ? EchoTheme.owned : Color.clear, lineWidth: 2))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(friend.name).font(EchoTheme.label(15, weight: 600)).foregroundColor(.white)
                                        Text(loading == friend.id ? "Opening…" : statusText(friend.status))
                                            .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                                    }
                                    Spacer()
                                    EchoGlyph(icon: .forward, size: 18).foregroundColor(EchoTheme.dim)
                                }
                                .padding(8)
                                .echoSurface()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}
