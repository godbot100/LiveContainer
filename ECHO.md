# Echo Launcher (iOS)

A fork of [LiveContainer](https://github.com/LiveContainer/LiveContainer) (AGPL-3.0) that installs, updates and
launches the Echo 3.6 iOS client. LiveContainer's loader, signing and JIT-less support are used unchanged.

## Stages

1. **Core** - single-game mode: install the game IPA named by the manifest, verify it, launch it with EchoIOS
   loaded from the tweak folder.
2. **Updates** - game IPA, EchoIOS, EchoGfx and paks update from the manifest; dylibs are re-signed on the
   device with the imported certificate (LiveContainer's ZSign path).
3. **Renderer switch** - "Echo (PC shaders)" or "Stock". Stock leaves out EchoGfx, the paks tagged
   `renderer: "echo"` and the extra command-line arguments.
4. **Mods** - list, download and toggle the backend's mods that carry an iOS pak.
5. **Launcher features** - sign-in, news, store, then the rest of the PC launcher's screens.

## Manifest (draft, served by the Echo backend over HTTPS)

```json
{
  "version": 1,
  "game":   { "build": "3.6-CL-4019403", "url": "https://.../game.ipa", "sha256": "...", "size": 0 },
  "client": [
    { "name": "EchoIOS.dylib", "build": 1, "url": "https://...", "sha256": "..." },
    { "name": "EchoGfx.dylib", "build": 1, "url": "https://...", "sha256": "...", "renderer": "echo" }
  ],
  "paks": [
    { "name": "pakchunkpadfix-iosclient_p", "pak": { "url": "...", "sha256": "..." }, "sig": { "url": "...", "sha256": "..." } },
    { "name": "pakchunkmetalmrt-iosclient_p", "renderer": "echo", "pak": { "url": "...", "sha256": "..." }, "sig": { "url": "...", "sha256": "..." } }
  ],
  "commandLine": { "all": [], "echo": ["-metaltlv"], "stock": [] },
  "settings": { "echo-ios.ini": { "url": "...", "sha256": "..." } }
}
```

Rules the launcher enforces: HTTPS only; every file is checked against its sha256 before it is used; a pak
name may appear once; file names may not contain path separators; entries tagged `renderer` are used only
when that renderer is selected; nothing is installed while the game is running.

## Status

- [x] Fork branch, display name
- [x] Bundle identifier rename (com.godbot100.echolauncher)
- [ ] URL scheme rename
- [x] Echo tab: manifest check, client library updates, game IPA download with integrity check
- [x] Built-in EchoIOS (Resources/EchoIOS.dylib.bin) installed into the tweak folder until a manifest supplies one
- [ ] Paks, command line, locking the app list to the one game
- [x] Renderer setting (switches the tagged client libraries)
- [ ] Mods

## Backend

The manifest is served by the Echo backend at `GET /launcher/ios/manifest`; files at
`GET /launcher/ios/file/<sha256>`. `game` is `null` until a `game.ipa` is published. Files are published
through the dashboard API (`POST /dashboard/api/ios-launcher/files/<name>`, owner only) or
`node packages/backend/scripts/publish-ios-launcher-file.js <file> [name]` on the server. Accepted names:
`game.ipa`, `EchoIOS.dylib`, `EchoGfx.dylib` (Echo renderer only), `pakchunk<name>-iosclient_p.pak` / `.sig`.

## Sign-in and server calls

Same as the PC launcher (`EchoAccount.swift`):

- Sign-in opens `<backend>/launcher/oauth/login?challenge=<base64url(sha256(verifier))>` in an
  `ASWebAuthenticationSession` that catches the `echo://callback?code=&state=` return, then posts
  `{code, state, verifier}` to `/launcher/oauth/exchange`. The returned token is kept in the keychain.
- Every later call sends `Authorization: bearer eg1~<token>` and the User-Agent
  `EchoLauncher/<version> (iOS; +https://echofn.org)`.
- Used routes: `/launcher/news`, `/launcher/servers`, `/launcher/shop`, `/launcher/vbucks`,
  `/launcher/account/credentials`, `/launcher/ios/manifest`.
- The backend is the origin of the manifest address (Settings, Game); default `https://api.echofn.org`.
- Not used on purpose: `/launcher/session`, `/launcher/game-nonce` and `/launcher/events`. Those drive the
  PC launch grant and official-launcher checks, which mobile logins are exempt from; the game signs in with
  the email and password shown on the Profile page.

## Content updates without a new launcher or IPA

Everything published on the dashboard (Paks, iOS) reaches players at the next launcher start or PLAY:

- **Libraries** (`EchoIOS.dylib`, `EchoGfx.dylib`): replaced inside the game when the hash differs, then the game is signed again.
- **Paks** (`pakchunk<name>-iosclient_p.pak` and `.sig`): downloaded into the game's paks folder, hash-checked. A pak the
  launcher installed and the server no longer lists is removed; paks that came with the game are never deleted.
  A pak marked as an Echo-renderer pak is kept as `.disabled` while the Stock renderer is selected.
- **Launch arguments**: the manifest's `all`, `echo` and `stock` lists are written into `ue4commandline.txt`; arguments
  the server stops listing are taken out again.
- The last manifest is cached, so an offline launch keeps the same content. A failed check never blocks PLAY.

## Client library updates

The launcher ships its own `EchoIOS.dylib` and `EchoGfx.dylib` (`Resources/*.dylib.bin`). A game build that
carries its own `EchoIOS.dylib` in `Frameworks/` gets it replaced once per launcher build (tracked by hash
under `EchoEmbeddedInGameSHA256:<name>`), so a library update reaches players without a new game IPA. A server
manifest that lists the same file is applied after that and wins.

`EchoGfx.dylib` is different: it belongs to the build's shader paks, so the build's own copy is kept
(`EmbeddedFile.replacesInGame`). Launcher builds 8fa8c55 to 81b70f9 replaced it with EchoGfx 12, which crashed
builds made for EchoGfx 14 (v52 and later) as soon as PC shaders were on; that one copy is the only one the
launcher still replaces, with the EchoGfx 14 it ships now (taken from the v54 game build). `EchoIOS.dylib.bin`
must be the `EchoIOS-gfx.dylib` build, the one that loads EchoGfx.

Settings, Game, "Edit styles in the locker" writes `LockerStyles=0/1` to the game's
`Documents/echo-ios.ini`, which EchoIOS reads at start.
