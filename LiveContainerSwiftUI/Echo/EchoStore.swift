//
//  EchoStore.swift
//  Echo Launcher
//
//  Keeps the Echo client libraries (EchoIOS, and EchoGfx for the PC-shader renderer) in place for the
//  installed game, from the copies shipped in this launcher or from the server manifest, and hands the
//  game IPA to LiveContainer's own installer.
//
//  Where the libraries live depends on the game build:
//  - A build whose executable already loads Frameworks/EchoIOS.dylib (every Echo test IPA): the libraries
//    inside the installed game's Frameworks folder are the ones that load, so they are managed there.
//    EchoGfx is loaded weakly by EchoIOS, so renaming it to ".disabled" is what switches to the stock renderer.
//  - A plain build: the libraries go in LiveContainer's global tweak folder, where ".disabled" is skipped too.
//

import Foundation
import CryptoKit
import SwiftUI

@MainActor
final class EchoStore: ObservableObject {
    static let manifestKey = "EchoManifestURL"
    static let rendererKey = "EchoRenderer"
    static let installedGameKey = "EchoInstalledGameSHA256"
    static let embeddedKeyPrefix = "EchoEmbeddedSHA256:"
    static let rendererArgument = "-metalmrt"
    static let embeddedGfxSettings = "3 2 1\n"

    /// Client libraries shipped inside the launcher, used until a manifest supplies newer ones.
    /// Stored in the app bundle as "<name>.bin" so the build does not treat them as code to link.
    struct EmbeddedFile {
        var name: String
        var renderer: String?
    }
    static let embeddedFiles = [
        EmbeddedFile(name: "EchoIOS.dylib", renderer: nil),
        EmbeddedFile(name: "EchoGfx.dylib", renderer: "echo"),
    ]

    static func savedManifestAddress() -> String {
        let saved = UserDefaults.standard.string(forKey: EchoStore.manifestKey) ?? ""
        return saved.isEmpty ? EchoAPI.defaultBackend + EchoAPI.manifestPath : saved
    }

    @Published var manifestAddress: String = EchoStore.savedManifestAddress()
    @Published var renderer: EchoRenderer = EchoRenderer(rawValue: UserDefaults.standard.string(forKey: EchoStore.rendererKey) ?? "") ?? .echo
    @Published var manifest: EchoManifest?
    @Published var status: String = ""
    @Published var busy = false
    @Published var progress: Double = 0

    /// The installed game's bundle folder, set by the view. nil while no game is installed.
    var gameBundle: URL?

    var gameNeedsInstall: Bool {
        guard let game = manifest?.game else { return false }
        return UserDefaults.standard.string(forKey: EchoStore.installedGameKey)?.lowercased() != game.sha256.lowercased()
    }

    // MARK: locations

    private var tweakFolder: URL { LCPath.tweakPath }

    private var gameFrameworks: URL? {
        gameBundle?.appendingPathComponent("Frameworks")
    }

    /// True when the game build loads EchoIOS from its own Frameworks folder.
    var gameCarriesClient: Bool {
        guard let frameworks = gameFrameworks else { return false }
        return FileManager.default.fileExists(atPath: frameworks.appendingPathComponent("EchoIOS.dylib").path)
    }

    /// True when the installed build includes the converted PC shader pak EchoGfx needs.
    var gameHasPcShaders: Bool {
        guard let bundle = gameBundle else { return false }
        let pak = bundle.appendingPathComponent("cookeddata/fortnitegame/content/paks/pakchunkzmetalmrt-iosclient_p.pak")
        return FileManager.default.fileExists(atPath: pak.path)
    }

    /// The renderer that will really be used: the PC-shader renderer only on a build that has its shaders.
    var effectiveRenderer: EchoRenderer {
        renderer == .echo && gameHasPcShaders ? .echo : .stock
    }

    // MARK: PC meshes

    /// The high-detail PC mesh pak some builds ship. Renaming it to ".disabled" makes the game skip it.
    private static let pcMeshFiles = ["pakchunkpcmeshes-iosclient_p.pak", "pakchunkpcmeshes-iosclient_p.sig"]

    private func pcMeshCopies(_ name: String) -> (enabled: URL, disabled: URL)? {
        guard let folder = gameBundle?.appendingPathComponent("cookeddata/fortnitegame/content/paks") else { return nil }
        return copies(of: name, in: folder)
    }

    var gameHasPcMeshes: Bool {
        guard let pak = pcMeshCopies(EchoStore.pcMeshFiles[0]) else { return false }
        return FileManager.default.fileExists(atPath: pak.enabled.path) || FileManager.default.fileExists(atPath: pak.disabled.path)
    }

    var pcMeshesEnabled: Bool {
        guard let pak = pcMeshCopies(EchoStore.pcMeshFiles[0]) else { return false }
        return FileManager.default.fileExists(atPath: pak.enabled.path)
    }

    func setPcMeshes(_ enabled: Bool) {
        let fm = FileManager.default
        do {
            for name in EchoStore.pcMeshFiles {
                guard let file = pcMeshCopies(name) else { continue }
                let from = enabled ? file.disabled : file.enabled
                let to = enabled ? file.enabled : file.disabled
                guard fm.fileExists(atPath: from.path) else { continue }
                if fm.fileExists(atPath: to.path) {
                    try fm.removeItem(at: to)
                }
                try fm.moveItem(at: from, to: to)
            }
            status = enabled ? "PC meshes: on" : "PC meshes: off"
        } catch {
            status = error.localizedDescription
        }
        objectWillChange.send()
    }

    private var clientFolder: URL {
        if gameCarriesClient, let frameworks = gameFrameworks { return frameworks }
        return tweakFolder
    }

    /// Name and renderer tag of every client library this launcher manages, embedded or from the manifest.
    private var managedClientFiles: [(name: String, renderer: String?)] {
        var files: [(name: String, renderer: String?)] = EchoStore.embeddedFiles.map { ($0.name, $0.renderer) }
        for file in manifest?.client ?? [] where !files.contains(where: { $0.name == file.name }) {
            files.append((file.name, file.renderer))
        }
        return files
    }

    private func copies(of name: String, in folder: URL) -> (enabled: URL, disabled: URL) {
        (folder.appendingPathComponent(name), folder.appendingPathComponent(name + ".disabled"))
    }

    // MARK: built-in libraries

    /// Puts the libraries shipped in the launcher in place. Returns true when a file inside the game
    /// bundle was added, which means the game needs signing again before it can start without JIT.
    @discardableResult
    func installEmbedded() -> Bool {
        let fm = FileManager.default
        var changedGame = false
        do {
            let inGame = gameCarriesClient
            let folder = clientFolder
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in EchoStore.embeddedFiles {
                guard let source = Bundle.main.url(forResource: file.name, withExtension: "bin") else {
                    status = "\(file.name) is missing from this launcher build"
                    continue
                }
                let target = copies(of: file.name, in: folder)
                let present = fm.fileExists(atPath: target.enabled.path) || fm.fileExists(atPath: target.disabled.path)
                let key = EchoStore.embeddedKeyPrefix + file.name
                if inGame {
                    // the build brought its own copy: keep it, and drop any copy this launcher put in the tweak folder
                    let stray = copies(of: file.name, in: tweakFolder)
                    if UserDefaults.standard.string(forKey: key) != nil {
                        for old in [stray.enabled, stray.disabled] where fm.fileExists(atPath: old.path) {
                            try fm.removeItem(at: old)
                        }
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    if present { continue }
                    try fm.copyItem(at: source, to: target.enabled)
                    changedGame = true
                    status = "Added the built-in \(file.name) to the game"
                } else {
                    let embeddedHash = try EchoStore.sha256(of: source)
                    if present, UserDefaults.standard.string(forKey: key) == embeddedHash { continue }
                    for old in [target.enabled, target.disabled] where fm.fileExists(atPath: old.path) {
                        try fm.removeItem(at: old)
                    }
                    try fm.copyItem(at: source, to: target.enabled)
                    UserDefaults.standard.set(embeddedHash, forKey: key)
                    status = "Installed the built-in \(file.name)"
                }
            }
            if let bundle = gameBundle {
                let settings = bundle.appendingPathComponent("echo-gfx.ini")
                if !fm.fileExists(atPath: settings.path) {
                    try EchoStore.embeddedGfxSettings.write(to: settings, atomically: true, encoding: .utf8)
                }
            }
            try applyRenderer()
        } catch {
            status = error.localizedDescription
        }
        return changedGame
    }

    // MARK: renderer

    func saveAddress() {
        UserDefaults.standard.set(manifestAddress.trimmingCharacters(in: .whitespacesAndNewlines), forKey: EchoStore.manifestKey)
    }

    func setRenderer(_ value: EchoRenderer) {
        renderer = value
        UserDefaults.standard.set(value.rawValue, forKey: EchoStore.rendererKey)
        do {
            try applyRenderer()
            status = value == .echo && gameBundle != nil && !gameHasPcShaders
                ? "This build has no PC shader paks, so it stays on the stock renderer"
                : "Renderer: \(value.title)"
        } catch {
            status = error.localizedDescription
        }
    }

    /// Libraries tagged for the other renderer are renamed to ".disabled", and the game's command line
    /// gets or loses the PC-shader renderer argument to match.
    private func applyRenderer() throws {
        let fm = FileManager.default
        let folder = clientFolder
        for file in managedClientFiles {
            let name = try safeName(file.name)
            let target = copies(of: name, in: folder)
            let wanted = file.renderer == nil || file.renderer == effectiveRenderer.rawValue
            if wanted, fm.fileExists(atPath: target.disabled.path), !fm.fileExists(atPath: target.enabled.path) {
                try fm.moveItem(at: target.disabled, to: target.enabled)
            } else if !wanted, fm.fileExists(atPath: target.enabled.path) {
                if fm.fileExists(atPath: target.disabled.path) {
                    try fm.removeItem(at: target.disabled)
                }
                try fm.moveItem(at: target.enabled, to: target.disabled)
            }
        }
        try applyCommandLine()
    }

    private func applyCommandLine() throws {
        guard let file = gameBundle?.appendingPathComponent("ue4commandline.txt"),
              FileManager.default.fileExists(atPath: file.path) else { return }
        let current = try String(contentsOf: file, encoding: .utf8)
        var words = current.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" }).map(String.init)
        let has = words.contains(EchoStore.rendererArgument)
        if effectiveRenderer == .echo, !has {
            words.append(EchoStore.rendererArgument)
        } else if effectiveRenderer == .stock, has {
            words.removeAll { $0 == EchoStore.rendererArgument }
        } else {
            return
        }
        try words.joined(separator: " ").write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: manifest

    private func httpsURL(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.lowercased() == "https" else {
            throw EchoError.message("Every address must use HTTPS: \(text)")
        }
        return url
    }

    private func safeName(_ name: String) throws -> String {
        if name.isEmpty || name.contains("/") || name.contains("\\") || name.hasPrefix(".") {
            throw EchoError.message("The manifest has an invalid file name: \(name)")
        }
        return name
    }

    /// Returns true when a library inside the game bundle was replaced (the game then needs signing again).
    @discardableResult
    func refresh() async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            saveAddress()
            let url = try httpsURL(manifestAddress)
            status = "Checking for updates"
            var request = EchoAPI.request(url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw EchoError.message("The manifest request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
            }
            let decoded = try JSONDecoder().decode(EchoManifest.self, from: data)
            guard decoded.version == 1 else {
                throw EchoError.message("This launcher is too old for the manifest (version \(decoded.version))")
            }
            manifest = decoded
            let changedGame = try await syncClient(decoded)
            status = decoded.game == nil ? "The server has no game published yet" : (gameNeedsInstall ? "Game install needed" : "Up to date")
            return changedGame
        } catch {
            status = error.localizedDescription
            return false
        }
    }

    private func syncClient(_ manifest: EchoManifest) async throws -> Bool {
        let fm = FileManager.default
        let inGame = gameCarriesClient
        let folder = clientFolder
        var changedGame = false
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = manifest.client ?? []
        for (index, file) in files.enumerated() {
            let name = try safeName(file.name)
            let target = copies(of: name, in: folder)
            let existing = fm.fileExists(atPath: target.enabled.path) ? target.enabled : (fm.fileExists(atPath: target.disabled.path) ? target.disabled : nil)
            if let existing, let have = try? EchoStore.sha256(of: existing), have == file.sha256.lowercased() {
                continue
            }
            status = "Downloading \(name)"
            progress = Double(index) / Double(max(files.count, 1))
            let temp = try await download(try httpsURL(file.url), expecting: file.sha256)
            for old in [target.enabled, target.disabled] where fm.fileExists(atPath: old.path) {
                try fm.removeItem(at: old)
            }
            try fm.moveItem(at: temp, to: target.enabled)
            if inGame { changedGame = true }
        }
        progress = 1
        try applyRenderer()
        return changedGame
    }

    // MARK: game

    func installGame() async {
        guard !busy, let game = manifest?.game else { return }
        busy = true
        defer { busy = false }
        do {
            status = "Downloading Fortnite"
            progress = 0
            let temp = try await download(try httpsURL(game.url), expecting: game.sha256)
            let ipa = FileManager.default.temporaryDirectory.appendingPathComponent("EchoGame.ipa")
            if FileManager.default.fileExists(atPath: ipa.path) {
                try FileManager.default.removeItem(at: ipa)
            }
            try FileManager.default.moveItem(at: temp, to: ipa)
            UserDefaults.standard.set(game.sha256.lowercased(), forKey: EchoStore.installedGameKey)
            status = "Installing Fortnite"
            DataManager.shared.model.selectedTab = .apps
            // the app list only listens once its tab has been shown
            try? await Task.sleep(nanoseconds: 700_000_000)
            NotificationCenter.default.post(name: NSNotification.InstallAppNotification, object: ["url": ipa])
        } catch {
            status = error.localizedDescription
        }
    }

    // MARK: download + integrity

    private func download(_ url: URL, expecting sha256: String) async throws -> URL {
        let (location, response) = try await URLSession.shared.download(for: EchoAPI.request(url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EchoError.message("Download failed: \(url.lastPathComponent)")
        }
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("echo-" + UUID().uuidString)
        try FileManager.default.moveItem(at: location, to: kept)
        let have = try await Task.detached { try EchoStore.sha256(of: kept) }.value
        guard have == sha256.lowercased() else {
            try? FileManager.default.removeItem(at: kept)
            throw EchoError.message("\(url.lastPathComponent) failed its integrity check")
        }
        return kept
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
