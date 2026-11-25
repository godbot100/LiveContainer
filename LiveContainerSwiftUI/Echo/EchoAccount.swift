//
//  EchoAccount.swift
//  Echo Launcher
//
//  The same sign-in and server calls the PC launcher makes: Discord sign-in through the Echo
//  backend (verifier and challenge, then /launcher/oauth/exchange), and every later call carrying
//  "Authorization: bearer eg1~<token>". The token is kept in the keychain.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

enum EchoAPI {
    static let defaultBackend = "https://api.echofn.org"
    static let manifestPath = "/launcher/ios/manifest"

    /// The backend is the server the manifest address points at, so there is one server setting.
    static func backend(forManifest address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: trimmed), parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty else {
            return defaultBackend
        }
        if let port = parts.port {
            return "https://\(host):\(port)"
        }
        return "https://\(host)"
    }

    static var backend: String {
        backend(forManifest: UserDefaults.standard.string(forKey: EchoStore.manifestKey) ?? "")
    }

    static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return "EchoLauncher/\(version) (iOS; +https://echofn.org)"
    }

    static func request(_ url: URL, method: String = "GET", token: String? = nil, json: [String: Any]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("bearer eg1~\(token)", forHTTPHeaderField: "Authorization")
        }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    /// Sends a request and returns the HTTP status with the decoded JSON body (nil when the body is not JSON).
    static func send(_ path: String, method: String = "GET", token: String? = nil, json: [String: Any]? = nil) async throws -> (status: Int, body: Any?, text: String) {
        guard let url = URL(string: backend + path) else { throw EchoError.message("The server address is not valid") }
        let (data, response) = try await URLSession.shared.data(for: request(url, method: method, token: token, json: json))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = try? JSONSerialization.jsonObject(with: data)
        let text = String(data: data.prefix(200), encoding: .utf8) ?? ""
        return (status, body, text)
    }
}

enum EchoKeychain {
    private static let service = "com.godbot100.echolauncher.session"
    private static let account = "launcher-token"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ token: String?) {
        SecItemDelete(query as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}

struct EchoNewsItem: Identifiable {
    var id: String
    var title: String
    var body: String
    var image: URL?
    var pinned: Bool
}

struct EchoServerRow: Identifiable {
    var id: String
    var playlist: String
    var region: String
    var status: String
    var players: Int
    var idle: Bool
}

struct EchoShopItem: Identifiable {
    var id: String
    var name: String
    var rarity: String
    var price: Int?
    var icon: URL?
}

@MainActor
private final class EchoSignInAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

@MainActor
final class EchoAccount: ObservableObject {
    private static let usernameKey = "EchoAccountUsername"
    private static let avatarKey = "EchoAccountAvatar"
    private static let accountIdKey = "EchoAccountId"

    @Published private(set) var signedIn = false
    @Published private(set) var username = UserDefaults.standard.string(forKey: EchoAccount.usernameKey) ?? ""
    @Published private(set) var avatar = UserDefaults.standard.string(forKey: EchoAccount.avatarKey) ?? ""
    @Published private(set) var accountId = UserDefaults.standard.string(forKey: EchoAccount.accountIdKey) ?? ""
    @Published private(set) var busy = false
    @Published var status = ""
    @Published private(set) var banNotice = ""

    @Published private(set) var vbucks: Int?
    @Published private(set) var gameEmail = ""
    @Published private(set) var gamePassword = ""
    @Published private(set) var news: [EchoNewsItem] = []
    @Published private(set) var servers: [EchoServerRow] = []
    @Published private(set) var playersInMatch = 0
    @Published private(set) var playersInQueue = 0
    @Published private(set) var shopFeatured: [EchoShopItem] = []
    @Published private(set) var shopDaily: [EchoShopItem] = []

    private var token: String?
    private var webSession: ASWebAuthenticationSession?
    private let anchor = EchoSignInAnchor()

    init() {
        token = EchoKeychain.read()
        signedIn = token != nil
    }

    // MARK: sign-in

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func newVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw EchoError.message("could not generate a sign-in verifier")
        }
        return base64URL(Data(bytes))
    }

    func signIn() async {
        guard !busy else { return }
        busy = true
        status = "Opening Discord sign-in…"
        banNotice = ""
        defer { busy = false }
        do {
            let verifier = try EchoAccount.newVerifier()
            let challenge = EchoAccount.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
            guard let loginURL = URL(string: "\(EchoAPI.backend)/launcher/oauth/login?challenge=\(challenge)") else { throw EchoError.message("The server address is not valid") }
            let callback = try await openSignIn(loginURL)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let code = items.first { $0.name == "code" }?.value ?? ""
            let state = items.first { $0.name == "state" }?.value ?? ""
            guard !code.isEmpty, !state.isEmpty else { throw EchoError.message("the sign-in page returned no code") }

            status = "Signing in…"
            let reply = try await EchoAPI.send("/launcher/oauth/exchange", method: "POST", json: ["code": code, "state": state, "verifier": verifier])
            let fields = reply.body as? [String: Any] ?? [:]
            if (fields["error"] as? String) == "banned" {
                banNotice = EchoAccount.banText(fields)
                status = ""
                return
            }
            guard reply.status == 200, let newToken = fields["token"] as? String, !newToken.isEmpty else {
                throw EchoError.message(EchoAccount.failureText(reply.status, fields, reply.text))
            }
            token = newToken
            EchoKeychain.write(newToken)
            remember(username: fields["username"] as? String ?? "", avatar: fields["avatar"] as? String ?? "", accountId: fields["accountId"] as? String ?? "")
            signedIn = true
            status = ""
            await refreshAll()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            status = ""
        } catch {
            status = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    private func openSignIn(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "echo") { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: error ?? EchoError.message("the sign-in page closed"))
                }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            if !session.start() {
                continuation.resume(throwing: EchoError.message("the sign-in page could not open"))
            }
        }
    }

    func signOut() {
        token = nil
        EchoKeychain.write(nil)
        signedIn = false
        remember(username: "", avatar: "", accountId: "")
        vbucks = nil
        gameEmail = ""
        gamePassword = ""
        news = []
        servers = []
        shopFeatured = []
        shopDaily = []
    }

    private func remember(username: String, avatar: String, accountId: String) {
        self.username = username
        self.avatar = avatar
        self.accountId = accountId
        UserDefaults.standard.set(username, forKey: EchoAccount.usernameKey)
        UserDefaults.standard.set(avatar, forKey: EchoAccount.avatarKey)
        UserDefaults.standard.set(accountId, forKey: EchoAccount.accountIdKey)
    }

    private static func banText(_ fields: [String: Any]) -> String {
        let reason = fields["banReason"] as? String ?? ""
        let until = fields["expiresAt"] as? String ?? ""
        var text = "This account is banned"
        if !reason.isEmpty { text += ": \(reason)" }
        if !until.isEmpty { text += " (until \(until.prefix(10)))" }
        return text + "."
    }

    private static func failureText(_ status: Int, _ fields: [String: Any], _ text: String) -> String {
        if let message = fields["message"] as? String, !message.isEmpty { return message }
        if let message = fields["errorMessage"] as? String, !message.isEmpty { return message }
        if status == 403 { return "the server refused this launcher (HTTP 403)" }
        if text.hasPrefix("<") || text.isEmpty { return "HTTP \(status)" }
        return "HTTP \(status): \(text)"
    }

    // MARK: server data

    /// One signed-in GET. A 401 means the session ended, so the launcher signs out like the PC one does.
    private func get(_ path: String) async -> Any? {
        guard let token else { return nil }
        do {
            let reply = try await EchoAPI.send(path, token: token)
            if reply.status == 401 {
                signOut()
                status = "Your session ended. Sign in again."
                return nil
            }
            let fields = reply.body as? [String: Any] ?? [:]
            if reply.status == 403, (fields["error"] as? String) == "banned" || fields["banReason"] != nil {
                banNotice = EchoAccount.banText(fields)
                return nil
            }
            guard reply.status == 200 else {
                status = "\(path): \(EchoAccount.failureText(reply.status, fields, reply.text))"
                return nil
            }
            return reply.body
        } catch {
            status = "\(path): \(error.localizedDescription)"
            return nil
        }
    }

    func refreshAll() async {
        guard signedIn else { return }
        status = ""
        await refreshProfile()
        await refreshNews()
        await refreshServers()
        await refreshShop()
    }

    func refreshProfile() async {
        if let fields = await get("/launcher/vbucks") as? [String: Any] {
            vbucks = EchoAccount.int(fields["vbucks"])
        }
        if let fields = await get("/launcher/account/credentials") as? [String: Any] {
            gameEmail = fields["email"] as? String ?? ""
            gamePassword = fields["password"] as? String ?? ""
        }
    }

    func refreshNews() async {
        guard let rows = await get("/launcher/news") as? [[String: Any]] else { return }
        news = rows.enumerated().map { index, row in
            let title = row["title"] as? String ?? ""
            return EchoNewsItem(
                id: EchoAccount.text(row["id"] ?? row["_id"]) ?? "\(index)|\(title)",
                title: title,
                body: row["body"] as? String ?? "",
                image: EchoAccount.url(row["image"]),
                pinned: row["pinned"] as? Bool ?? false)
        }
    }

    func refreshServers() async {
        guard let fields = await get("/launcher/servers") as? [String: Any] else { return }
        let rows = fields["servers"] as? [[String: Any]] ?? []
        servers = rows.enumerated().map { index, row in
            EchoServerRow(
                id: EchoAccount.text(row["sessionId"]) ?? "\(index)",
                playlist: row["playlistName"] as? String ?? row["playlistId"] as? String ?? "Server",
                region: row["region"] as? String ?? "",
                status: row["status"] as? String ?? "",
                players: EchoAccount.int(row["playerCount"]) ?? 0,
                idle: row["idle"] as? Bool ?? false)
        }
        let summary = fields["summary"] as? [String: Any] ?? [:]
        playersInMatch = EchoAccount.int(summary["playersInMatch"]) ?? 0
        playersInQueue = EchoAccount.int(summary["playersInQueue"]) ?? 0
    }

    func refreshShop() async {
        guard let fields = await get("/launcher/shop") as? [String: Any] else { return }
        let panels = fields["panels"] as? [[String: Any]] ?? []
        let featured = panels.flatMap { $0["items"] as? [[String: Any]] ?? [] }
        shopFeatured = EchoAccount.shopItems(featured, prefix: "featured")
        shopDaily = EchoAccount.shopItems(fields["daily"] as? [[String: Any]] ?? [], prefix: "daily")
    }

    private static func shopItems(_ rows: [[String: Any]], prefix: String) -> [EchoShopItem] {
        rows.enumerated().map { index, row in
            EchoShopItem(
                id: "\(prefix)-\(index)",
                name: row["name"] as? String ?? "Item",
                rarity: row["rarity"] as? String ?? "",
                price: int(row["price"] ?? row["finalPrice"]),
                icon: url(row["icon"]))
        }
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        if let text = value as? String, !text.isEmpty { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func url(_ value: Any?) -> URL? {
        guard let text = value as? String, text.lowercased().hasPrefix("https://") else { return nil }
        return URL(string: text)
    }
}
