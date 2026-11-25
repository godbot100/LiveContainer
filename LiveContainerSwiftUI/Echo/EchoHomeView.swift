//
//  EchoHomeView.swift
//  Echo Launcher
//
//  The Echo shell: a navigation rail and the pages of the PC launcher (servers, store, home,
//  builds, profile, settings). Pages that need the Echo server show an empty state until it is connected.
//

import SwiftUI

enum EchoPage: Int, CaseIterable, Identifiable {
    case servers, store, home, builds, profile, settings
    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .servers: return "server.rack"
        case .store: return "bag.fill"
        case .home: return "house.fill"
        case .builds: return "square.grid.2x2.fill"
        case .profile: return "person.crop.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .servers: return Color(red: 0.75, green: 0.35, blue: 0.15)
        case .store: return Color(red: 0.25, green: 0.25, blue: 0.30)
        case .home: return Color(red: 0.20, green: 0.35, blue: 0.85)
        case .builds: return Color(red: 0.20, green: 0.55, blue: 0.30)
        case .profile: return Color(red: 0.55, green: 0.20, blue: 0.75)
        case .settings: return Color(red: 0.15, green: 0.20, blue: 0.80)
        }
    }
}

enum EchoSettingsPage {
    case root, mods, game, advanced
}

struct EchoHomeView: View {
    @StateObject private var store = EchoStore()
    @StateObject private var account = EchoAccount()
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var page: EchoPage = .home
    @State private var settingsPage: EchoSettingsPage = .root
    @State private var modsTab = 0
    @State private var mods: [EchoMod] = []
    @State private var launchError = ""

    private var game: LCAppModel? {
        sharedModel.apps.first { app in
            let identifier = (app.appInfo.bundleIdentifier() ?? "").lowercased()
            let name = (app.appInfo.displayName() ?? "").lowercased()
            return identifier.contains("fortnite") || name.contains("fortnite")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height
            ZStack {
                EchoBackground(tint: page.tint)
                if wide {
                    HStack(spacing: 0) {
                        rail(vertical: true)
                        pageContent
                    }
                } else {
                    VStack(spacing: 0) {
                        pageContent
                        rail(vertical: false)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .modifier(EchoHideTabBar())
        .task {
            await prepareClient(checkServer: true)
        }
        .task {
            await account.refreshAll()
        }
        .onChange(of: sharedModel.apps.count) { _ in
            Task { await prepareClient(checkServer: false) }
        }
    }

    // MARK: rail

    private func railButton(_ item: EchoPage) -> some View {
        Button(action: {
            page = item
            if item == .settings { settingsPage = .root }
        }) {
            Image(systemName: item.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(page == item ? .black : .white)
                .frame(width: 44, height: 44)
                .background(page == item ? EchoTheme.accent : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rail(vertical: Bool) -> some View {
        let main: [EchoPage] = [.servers, .store, .home, .builds, .profile]
        if vertical {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                    ForEach(main) { railButton($0) }
                }
                .padding(6)
                .background(EchoTheme.rail)
                .clipShape(Capsule())
                Spacer()
                railButton(.settings)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 14)
        } else {
            HStack(spacing: 6) {
                ForEach(main) { railButton($0) }
                railButton(.settings)
            }
            .padding(6)
            .background(EchoTheme.rail)
            .clipShape(Capsule())
            .padding(.bottom, 8)
        }
    }

    // MARK: pages

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .home: homePage
        case .servers: scrollPage { EchoServersPage(account: account) }
        case .store: scrollPage { EchoStorePage(account: account) }
        case .builds: scrollPage { buildsPage }
        case .profile: scrollPage { EchoProfilePage(account: account) }
        case .settings: scrollPage { settingsContent }
        }
    }

    private func scrollPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(24)
        }
    }

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            Text("ECHO")
                .font(EchoTheme.heading(86))
                .foregroundColor(.white)
            Text(game == nil ? "FORTNITE 3.6 · NOT INSTALLED" : "FORTNITE 3.6 · READY")
                .font(EchoTheme.heading(16))
                .foregroundColor(.white)
            if !account.signedIn {
                Button(account.busy ? "SIGNING IN…" : "SIGN IN WITH DISCORD") {
                    Task { await account.signIn() }
                }
                .buttonStyle(EchoPrimaryButtonStyle())
                .disabled(account.busy)
                if game != nil {
                    Button("Play without signing in") {
                        Task { await play() }
                    }
                    .font(EchoTheme.label(13))
                    .foregroundColor(EchoTheme.dim)
                }
            } else if game != nil {
                Button("PLAY") {
                    Task { await play() }
                }
                .buttonStyle(EchoPrimaryButtonStyle())
            } else {
                Button("INSTALL") {
                    page = .builds
                }
                .buttonStyle(EchoPrimaryButtonStyle())
            }
            if !launchError.isEmpty {
                Text(launchError)
                    .font(EchoTheme.label(13))
                    .foregroundColor(.red)
            }
            if !store.status.isEmpty {
                Text(store.status)
                    .font(EchoTheme.label(13))
                    .foregroundColor(EchoTheme.dim)
            }
            EchoAccountNotices(account: account)
            Spacer()
            EchoSectionTitle(text: "News")
            EchoNewsStrip(account: account)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var buildsPage: some View {
        Group {
            EchoPageHeader(title: "Builds", subtitle: "Manage your builds.")
            EchoSectionTitle(text: "Your builds")
            if sharedModel.apps.isEmpty {
                EchoEmptyState(symbol: "square.grid.2x2.fill", text: "No build is installed yet.")
            }
            ForEach(sharedModel.apps, id: \.self) { app in
                EchoCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((app.appInfo.displayName() ?? "Build").uppercased())
                                .font(EchoTheme.heading(18))
                                .foregroundColor(.white)
                            Text(app.appInfo.bundleIdentifier() ?? "")
                                .font(EchoTheme.label(12))
                                .foregroundColor(EchoTheme.dim)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(EchoTheme.owned)
                    }
                }
            }
            EchoSectionTitle(text: "Add a build")
            Button(action: { sharedModel.selectedTab = .apps }) {
                EchoCard {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from device").font(EchoTheme.label(15)).foregroundColor(.white)
                            Text("Opens the app list. Tap + there and choose the Fortnite 3.6 IPA.")
                                .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                        }
                    } icon: {
                        Image(systemName: "plus.circle.fill").foregroundColor(EchoTheme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            Button(action: { Task { await store.installGame() } }) {
                EchoCard {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download build").font(EchoTheme.label(15)).foregroundColor(.white)
                            Text(store.manifest?.game == nil ? "No build is published on the Echo server yet." : "Fortnite 3.6 from the Echo server.")
                                .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill").foregroundColor(EchoTheme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(store.busy || store.manifest?.game == nil)
            if store.busy {
                ProgressView()
            }
        }
    }

    // MARK: settings

    private func settingsCard(_ title: String, _ subtitle: String, _ symbol: String, _ target: EchoSettingsPage) -> some View {
        Button(action: {
            settingsPage = target
            if target == .mods { reloadMods() }
        }) {
            EchoCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(EchoTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(title.uppercased()).font(EchoTheme.heading(17)).foregroundColor(.white)
                        Text(subtitle).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundColor(EchoTheme.dim)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func backHeader(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top) {
            EchoPageHeader(title: title, subtitle: subtitle)
            Button(action: { settingsPage = .root }) {
                Label("Back", systemImage: "chevron.left")
                    .font(EchoTheme.label(13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(EchoTheme.card)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch settingsPage {
        case .root:
            EchoPageHeader(title: "Settings", subtitle: "Your account, the launcher and how it looks.")
            settingsCard("Mods", "Optional add-ons, applied the next time you launch", "star.fill", .mods)
            settingsCard("Game", "How Echo starts up and behaves in game", "gamecontroller.fill", .game)
            settingsCard("Advanced", "Certificates, app list and the LiveContainer settings", "wrench.and.screwdriver.fill", .advanced)
        case .mods:
            backHeader("Mods", "Optional add-ons, applied the next time you launch")
            EchoPillPicker(options: ["Installed \(mods.count)", "Marketplace"], selection: $modsTab)
            if modsTab == 0 {
                if mods.isEmpty {
                    EchoEmptyState(symbol: "star.fill", text: "Nothing is installed.")
                }
                ForEach(mods) { mod in
                    EchoCard {
                        Toggle(isOn: Binding(get: { mod.enabled }, set: { setMod(mod, enabled: $0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mod.title.uppercased()).font(EchoTheme.heading(16)).foregroundColor(mod.enabled ? .white : EchoTheme.dim)
                                Text("Applied next launch").font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                            }
                        }
                        .tint(EchoTheme.accent)
                    }
                }
            } else {
                EchoEmptyState(symbol: "square.grid.2x2.fill", text: "Nothing for iOS is published in the Echo mod catalog yet.")
            }
        case .game:
            backHeader("Game", "How Echo starts up and behaves in game")
            EchoSectionTitle(text: "Renderer")
            EchoPillPicker(options: EchoRenderer.allCases.map { $0.title }, selection: Binding(
                get: { EchoRenderer.allCases.firstIndex(of: store.renderer) ?? 0 },
                set: { store.setRenderer(EchoRenderer.allCases[$0]); reloadMods() }))
            Text("Stock uses the game's own iOS shaders. Echo loads EchoGfx and the converted PC shaders, which need a game build that includes the shader paks. Takes effect the next time the game starts.")
                .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
            EchoSectionTitle(text: "Server")
            EchoCard {
                TextField("https://", text: $store.manifestAddress)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
            }
            Button("CHECK FOR UPDATES") {
                Task { await prepareClient(checkServer: true) }
            }
            .buttonStyle(EchoPrimaryButtonStyle())
            .disabled(store.busy)
            if !store.status.isEmpty {
                Text(store.status).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
            }
        case .advanced:
            backHeader("Advanced", "Certificates, app list and the LiveContainer settings")
            advancedButton("App list", "Install, sign and manage builds", .apps)
            advancedButton("Tweaks", "Files loaded into the game", .tweaks)
            advancedButton("LiveContainer settings", "Signing certificate, JIT and storage", .settings)
        }
    }

    private func advancedButton(_ title: String, _ subtitle: String, _ tab: LCTabIdentifier) -> some View {
        Button(action: { sharedModel.selectedTab = tab }) {
            EchoCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.uppercased()).font(EchoTheme.heading(16)).foregroundColor(.white)
                        Text(subtitle).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundColor(EchoTheme.dim)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: actions

    /// Puts the client libraries in place for the installed game and signs the game again when one was added.
    private func prepareClient(checkServer: Bool) async {
        if let path = game?.appInfo.bundlePath() {
            store.gameBundle = URL(fileURLWithPath: path)
        } else {
            store.gameBundle = nil
        }
        // EchoGfx and EchoIOS find the game by asking for image 0. Without this LiveContainer setting image 0 is
        // the launcher itself, the hooks attach to nothing and the PC-shader renderer draws wrongly.
        if let game, !game.uiHideLiveContainer {
            game.uiHideLiveContainer = true
        }
        var changedGame = store.installEmbedded()
        if checkServer {
            if await store.refresh() { changedGame = true }
        }
        reloadMods()
        if changedGame, let game {
            do {
                try await game.forceResign()
            } catch {
                launchError = error.localizedDescription
            }
        }
    }

    private func play() async {
        guard let game else { return }
        launchError = ""
        await prepareClient(checkServer: false)
        do {
            try await game.runApp()
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func reloadMods() {
        mods = EchoMod.installed(in: LCPath.tweakPath)
    }

    private func setMod(_ mod: EchoMod, enabled: Bool) {
        do {
            try mod.setEnabled(enabled, in: LCPath.tweakPath)
        } catch {
            store.status = error.localizedDescription
        }
        reloadMods()
    }
}

struct EchoMod: Identifiable {
    var fileName: String
    var enabled: Bool
    var id: String { fileName }

    var title: String {
        fileName.replacingOccurrences(of: ".dylib", with: "")
    }

    static func installed(in folder: URL) -> [EchoMod] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var found: [EchoMod] = []
        for name in names.sorted() {
            if name.hasSuffix(".dylib.disabled") {
                found.append(EchoMod(fileName: String(name.dropLast(".disabled".count)), enabled: false))
            } else if name.hasSuffix(".dylib"), name != "TweakLoader.dylib" {
                found.append(EchoMod(fileName: name, enabled: true))
            }
        }
        return found
    }

    func setEnabled(_ value: Bool, in folder: URL) throws {
        let on = folder.appendingPathComponent(fileName)
        let off = folder.appendingPathComponent(fileName + ".disabled")
        let fm = FileManager.default
        if value, fm.fileExists(atPath: off.path), !fm.fileExists(atPath: on.path) {
            try fm.moveItem(at: off, to: on)
        } else if !value, fm.fileExists(atPath: on.path) {
            if fm.fileExists(atPath: off.path) {
                try fm.removeItem(at: off)
            }
            try fm.moveItem(at: on, to: off)
        }
    }
}
