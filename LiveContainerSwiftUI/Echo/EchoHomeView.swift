//
//  EchoHomeView.swift
//  Echo Launcher
//
//  The Echo shell, laid out like the PC launcher: a floating rail, the hero and news on Home,
//  Builds, Store, Servers, Profile and Settings, with the friends pill and the music player on top.
//

import SwiftUI

enum EchoPage: Int, CaseIterable, Identifiable {
    case home, builds, store, servers, profile, settings
    var id: Int { rawValue }

    var icon: EchoIcon {
        switch self {
        case .home: return .home
        case .builds: return .builds
        case .store: return .store
        case .servers: return .servers
        case .profile: return .person
        case .settings: return .settings
        }
    }

    var art: String {
        switch self {
        case .builds: return "EchoBgBuilds"
        case .settings: return "EchoBgSettings"
        default: return "EchoBgHome"
        }
    }
}

/// A graphics change that needs the performance warning before it is applied.
enum EchoGraphicsChange: Identifiable {
    case pcRenderer, pcMeshes
    var id: Int { self == .pcRenderer ? 0 : 1 }
}

enum EchoSettingsPage {
    case root, account, mods, game, appearance, diagnostics, advanced
}

struct EchoHomeView: View {
    @StateObject private var store = EchoStore()
    @StateObject private var account = EchoAccount()
    @StateObject private var music = EchoMusic()
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage(EchoTheme.themeKey) private var themeName = "Timeless"
    @State private var page: EchoPage = .home
    @State private var settingsPage: EchoSettingsPage = .root
    @State private var article: EchoNewsItem?
    @State private var modsTab = 0
    @State private var mods: [EchoMod] = []
    @State private var launchError = ""
    @State private var showPassword = false
    @State private var report = ""
    @State private var graphicsWarning: EchoGraphicsChange?

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
                EchoBackground(art: page.art, remote: page == .home ? article?.image : nil)
                if wide {
                    HStack(spacing: 0) {
                        rail(vertical: true)
                        pageContent(wide: true)
                    }
                } else {
                    VStack(spacing: 0) {
                        pageContent(wide: false)
                        rail(vertical: false)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if account.signedIn {
                    EchoFriendsPill(account: account).padding(.top, 14).padding(.trailing, 20)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                EchoMusicPlayer(music: music).padding(.bottom, wide ? 14 : 72).padding(.trailing, 20)
            }
        }
        .id(themeName)
        .alert(item: $graphicsWarning) { change in
            Alert(
                title: Text("Performance warning"),
                message: Text("PC-level \(change == .pcRenderer ? "shaders" : "meshes") are much heavier than the stock ones. Expect a lower frame rate, faster battery drain and a device that can get hot. Take a break if it becomes uncomfortable to hold."),
                primaryButton: .default(Text("Turn on")) {
                    if change == .pcRenderer {
                        store.setRenderer(.echo)
                        reloadMods()
                    } else {
                        store.setPcMeshes(true)
                    }
                },
                secondaryButton: .cancel())
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
        EchoIconButton(icon: item.icon, size: 46, active: page == item) {
            withAnimation(.easeOut(duration: 0.25)) {
                page = item
                settingsPage = .root
                article = nil
            }
        }
    }

    @ViewBuilder
    private func rail(vertical: Bool) -> some View {
        let main: [EchoPage] = [.home, .builds, .store, .servers]
        if vertical {
            VStack(spacing: 6) {
                ForEach(main) { railButton($0) }
                Spacer().frame(height: 10)
                railButton(.profile)
                railButton(.settings)
            }
            .padding(6)
            .echoSurface(radius: 100)
            .padding(.horizontal, 14)
        } else {
            HStack(spacing: 6) {
                ForEach(main) { railButton($0) }
                railButton(.profile)
                railButton(.settings)
            }
            .padding(6)
            .echoSurface(radius: 100)
            .padding(.bottom, 8)
        }
    }

    // MARK: pages

    @ViewBuilder
    private func pageContent(wide: Bool) -> some View {
        switch page {
        case .home:
            if let article {
                scrollPage { EchoArticlePage(account: account, item: article, open: { self.article = $0 }, close: { self.article = nil }) }
            } else if wide {
                HStack(alignment: .center, spacing: 24) {
                    hero
                    EchoHomeNews(account: account, open: { article = $0 })
                        .frame(maxWidth: 440)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                scrollPage {
                    hero
                    EchoHomeNews(account: account, open: { article = $0 })
                }
            }
        case .servers: scrollPage { EchoServersPage(account: account, openStore: { page = .store }) }
        case .store: scrollPage { EchoStorePage(account: account) }
        case .builds: scrollPage { buildsPage }
        case .profile: scrollPage { EchoProfilePage(account: account) }
        case .settings: scrollPage { settingsContent }
        }
    }

    private func scrollPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(24)
            .padding(.top, 20)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let logo = EchoTheme.image("EchoLogo", "png") {
                    Image(uiImage: logo).resizable().scaledToFit().frame(width: 78, height: 78)
                }
                Text("ECHO").font(EchoTheme.heading(96)).foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 12, y: 4)
            Text(game == nil ? "SEASON 3 · NOT INSTALLED" : "SEASON 3 · READY TO PLAY")
                .font(EchoTheme.caps(18))
                .foregroundColor(.white)
            if !account.signedIn {
                Button(account.busy ? "SIGNING IN…" : "SIGN IN") {
                    Task { await account.signIn() }
                }
                .buttonStyle(EchoPrimaryButtonStyle())
                .disabled(account.busy)
                if game != nil {
                    Button("Play without signing in") {
                        Task { await play() }
                    }
                    .buttonStyle(EchoButtonStyle(kind: .ghost))
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
            if game != nil {
                VStack(alignment: .leading, spacing: 8) {
                    graphicsControls
                }
                .frame(maxWidth: 360, alignment: .leading)
            }
            if !launchError.isEmpty {
                Text(launchError).font(EchoTheme.label(13)).foregroundColor(EchoTheme.red)
            }
            if !store.status.isEmpty {
                Text(store.status).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
            }
            EchoAccountNotices(account: account)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Renderer and mesh switches, shared by Home and Settings. Turning a PC option on asks first.
    @ViewBuilder
    private var graphicsControls: some View {
        if store.gameHasPcShaders {
            EchoPillPicker(options: EchoRenderer.allCases.map { $0.title }, selection: Binding(
                get: { EchoRenderer.allCases.firstIndex(of: store.renderer) ?? 0 },
                set: { index in
                    if EchoRenderer.allCases[index] == .echo {
                        if store.renderer != .echo { graphicsWarning = .pcRenderer }
                    } else {
                        store.setRenderer(.stock)
                        reloadMods()
                    }
                }))
        }
        if store.gameHasPcMeshes {
            Toggle(isOn: Binding(get: { store.pcMeshesEnabled }, set: { on in
                if on { graphicsWarning = .pcMeshes } else { store.setPcMeshes(false) }
            })) {
                Text("HIGH-QUALITY PC MESHES").font(EchoTheme.caps(14)).foregroundColor(.white)
            }
            .tint(EchoTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .echoSurface()
        }
        if store.effectiveRenderer == .echo || store.pcMeshesEnabled {
            Text("PC-level graphics are on: lower frame rate, more battery use, and the device can get hot.")
                .font(EchoTheme.label(12, weight: 600))
                .foregroundColor(EchoTheme.yellow)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionRow(_ icon: EchoIcon, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            EchoGlyph(icon: icon, size: 24).foregroundColor(EchoTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(EchoTheme.title(16)).foregroundColor(.white)
                Text(subtitle).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
            }
            Spacer()
            EchoGlyph(icon: .forward, size: 18).foregroundColor(EchoTheme.dim)
        }
        .padding(14)
        .echoSurface()
    }

    @ViewBuilder
    private var buildsPage: some View {
        EchoPageHeader(title: "Builds", subtitle: "Manage your builds.")
        if sharedModel.apps.isEmpty {
            EchoEmptyState(icon: .builds, title: "No builds", text: "No build is installed yet.")
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(sharedModel.apps, id: \.self) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        Color.clear
                            .aspectRatio(0.75, contentMode: .fit)
                            .overlay(LinearGradient(colors: [EchoTheme.accent.opacity(0.55), EchoTheme.tint], startPoint: .top, endPoint: .bottom))
                            .overlay(Text("3.6").font(EchoTheme.heading(54)).foregroundColor(.white))
                            .overlay(alignment: .topTrailing) { EchoTag(text: "Installed", badge: true).padding(8) }
                        Text((app.appInfo.displayName() ?? "Build").uppercased())
                            .font(EchoTheme.title(15)).foregroundColor(.white).lineLimit(1)
                            .padding(.horizontal, 10)
                        Text(app.appInfo.bundleIdentifier() ?? "")
                            .font(EchoTheme.label(10)).foregroundColor(EchoTheme.dim).lineLimit(1)
                            .padding(.horizontal, 10).padding(.bottom, 10)
                    }
                    .echoSurface(radius: EchoTheme.radiusLarge)
                }
            }
        }
        EchoSectionTitle(text: "Add a build")
        Button(action: { sharedModel.selectedTab = .apps }) {
            actionRow(.add, "Import from device", "Opens the app list. Tap + there and choose the Fortnite 3.6 IPA.")
        }
        .buttonStyle(.plain)
        Button(action: { Task { await store.installGame() } }) {
            actionRow(.download, "Download build", store.manifest?.game == nil ? "No build is published on the Echo server yet." : "Fortnite 3.6 from the Echo server.")
        }
        .buttonStyle(.plain)
        .disabled(store.busy || store.manifest?.game == nil)
        if store.busy {
            ProgressView().tint(EchoTheme.accent)
        }
    }

    // MARK: settings

    private func settingsTile(_ title: String, _ subtitle: String, _ icon: EchoIcon, _ target: EchoSettingsPage) -> some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.25)) { settingsPage = target }
            if target == .mods { reloadMods() }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                EchoGlyph(icon: icon, size: 26).foregroundColor(EchoTheme.accent)
                Text(title.uppercased()).font(EchoTheme.title(18)).foregroundColor(.white)
                Text(subtitle).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim).lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .echoSurface(radius: EchoTheme.radiusLarge)
        }
        .buttonStyle(.plain)
    }

    private func backHeader(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top) {
            EchoPageHeader(title: title, subtitle: subtitle)
            Button(action: { withAnimation(.easeOut(duration: 0.25)) { settingsPage = .root } }) {
                Label { Text("Settings") } icon: { EchoGlyph(icon: .back, size: 16) }
                    .font(EchoTheme.label(13, weight: 600))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .echoSurface(radius: 100)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyRow(_ title: String, _ value: String, shown: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                Text(shown).font(EchoTheme.label(15, weight: 600)).foregroundColor(.white).lineLimit(1)
            }
            Spacer()
            EchoIconButton(icon: .copy, size: 36) { UIPasteboard.general.string = value }
        }
        .padding(14)
        .echoSurface()
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch settingsPage {
        case .root:
            EchoPageHeader(title: "Settings", subtitle: "Your account, the launcher and how it looks.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                settingsTile("Account", "Sign-in and your game login", .person, .account)
                settingsTile("Mods", "Optional add-ons, applied the next time you launch", .star, .mods)
                settingsTile("Game", "How Echo starts up and behaves in game", .game, .game)
                settingsTile("Appearance", "The launcher's colour theme", .palette, .appearance)
                settingsTile("Diagnostics", "What the launcher set up, and the game's own logs", .stats, .diagnostics)
                settingsTile("Advanced", "Certificates, app list and the LiveContainer settings", .build, .advanced)
            }
        case .account:
            backHeader("Account", "Sign-in and your game login")
            if !account.signedIn {
                EchoSignInPrompt(account: account, text: "Sign in with the Discord account you use for Echo.")
            } else {
                copyRow("Signed in as", account.username, shown: account.username)
                if !account.gameEmail.isEmpty {
                    EchoSectionTitle(text: "Game sign-in")
                    copyRow("Email", account.gameEmail, shown: account.gameEmail)
                    copyRow("Password", account.gamePassword, shown: showPassword ? account.gamePassword : String(repeating: "•", count: 10))
                    Button(showPassword ? "Hide password" : "Show password") {
                        showPassword.toggle()
                    }
                    .buttonStyle(EchoButtonStyle(kind: .ghost))
                }
                Button("Sign out") {
                    account.signOut()
                }
                .buttonStyle(EchoButtonStyle(kind: .danger))
                EchoAccountNotices(account: account)
            }
        case .mods:
            backHeader("Mods", "Optional add-ons, applied the next time you launch")
            EchoPillPicker(options: ["Installed \(mods.count)", "Marketplace"], selection: $modsTab)
            if modsTab == 0 {
                if mods.isEmpty {
                    EchoEmptyState(icon: .star, title: "No mods", text: "Nothing is installed.")
                }
                ForEach(mods) { mod in
                    Toggle(isOn: Binding(get: { mod.enabled }, set: { setMod(mod, enabled: $0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mod.title.uppercased()).font(EchoTheme.title(16)).foregroundColor(mod.enabled ? .white : EchoTheme.dim)
                            Text("Applied next launch").font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
                        }
                    }
                    .tint(EchoTheme.accent)
                    .padding(14)
                    .echoSurface()
                }
            } else {
                EchoEmptyState(icon: .builds, title: "Marketplace", text: "Nothing for iOS is published in the Echo mod catalog yet.")
            }
        case .game:
            backHeader("Game", "How Echo starts up and behaves in game")
            EchoSectionTitle(text: "Graphics")
            graphicsControls
            Text("Stock uses the game's own iOS shaders and switches off EchoGfx and the PC shader, material and texture paks. Echo switches them back on. Changes take effect the next time the game starts.")
                .font(EchoTheme.label(12)).foregroundColor(EchoTheme.dim)
            EchoSectionTitle(text: "Server")
            TextField("https://", text: $store.manifestAddress)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(EchoTheme.label(14))
                .foregroundColor(.white)
                .padding(14)
                .echoSurface()
            Button("Check for updates") {
                Task { await prepareClient(checkServer: true) }
            }
            .buttonStyle(EchoButtonStyle())
            .disabled(store.busy)
            if !store.status.isEmpty {
                Text(store.status).font(EchoTheme.label(13)).foregroundColor(EchoTheme.dim)
            }
        case .appearance:
            backHeader("Appearance", "The launcher's colour theme")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                ForEach(EchoPalette.all, id: \.name) { palette in
                    Button(action: {
                        EchoTheme.palette = palette
                        themeName = palette.name
                    }) {
                        HStack(spacing: 10) {
                            Circle().fill(palette.accent).frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Color.white, lineWidth: palette.name == EchoTheme.palette.name ? 2 : 0))
                            Text(palette.name).font(EchoTheme.label(14, weight: 600)).foregroundColor(.white)
                            Spacer()
                        }
                        .padding(12)
                        .echoSurface()
                    }
                    .buttonStyle(.plain)
                }
            }
        case .diagnostics:
            backHeader("Diagnostics", "What the launcher set up, and the game's own logs")
            HStack(spacing: 10) {
                Button("Refresh") { loadReport() }
                    .buttonStyle(EchoButtonStyle(kind: .ghost))
                Button("Copy") { UIPasteboard.general.string = report }
                    .buttonStyle(EchoButtonStyle())
            }
            Text(report.isEmpty ? "Nothing yet." : report)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .echoSurface()
                .onAppear { loadReport() }
        case .advanced:
            backHeader("Advanced", "Certificates, app list and the LiveContainer settings")
            advancedButton("App list", "Install, sign and manage builds", .apps)
            advancedButton("Tweaks", "Files loaded into the game", .tweaks)
            advancedButton("LiveContainer settings", "Signing certificate, JIT and storage", .settings)
        }
    }

    private func advancedButton(_ title: String, _ subtitle: String, _ tab: LCTabIdentifier) -> some View {
        Button(action: { sharedModel.selectedTab = tab }) {
            actionRow(.build, title, subtitle)
        }
        .buttonStyle(.plain)
    }

    // MARK: actions

    /// Puts the client libraries in place for the installed game and signs the game again when one was added.
    private func prepareClient(checkServer: Bool) async {
        let bundle = game?.appInfo.bundlePath().map { URL(fileURLWithPath: $0) }
        if store.gameBundle != bundle {
            store.gameBundle = bundle
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
        music.stop()
        await prepareClient(checkServer: false)
        // A JIT launch is carried out by the app list screen, which only exists once it has been shown.
        // Without it LiveContainer's launch call returns without doing anything.
        if game.appInfo.isJITNeeded, game.delegate == nil {
            sharedModel.selectedTab = .apps
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        do {
            try await game.runApp()
        } catch {
            launchError = error.localizedDescription
            return
        }
        // a successful launch replaces this screen; still being here means nothing started
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        launchError = "The game did not start. Open Settings, Advanced, App list and start it there once, then try again."
    }

    private func loadReport() {
        var container: URL?
        if let folder = game?.uiDefaultDataFolder, !folder.isEmpty {
            for root in [LCPath.dataPath, LCPath.lcGroupDataPath] {
                let candidate = root.appendingPathComponent(folder)
                if FileManager.default.fileExists(atPath: candidate.path) { container = candidate }
            }
        }
        report = store.diagnostics(hideLiveContainer: game?.uiHideLiveContainer ?? false, container: container)
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
