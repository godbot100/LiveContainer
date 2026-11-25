//
//  EchoMusic.swift
//  Echo Launcher
//
//  The PC launcher's music player: the same track list, streamed, collapsed to its art until opened.
//

import SwiftUI
import AVFoundation

struct EchoTrack: Identifiable {
    var name: String
    var icon: String
    var url: String
    var id: String { url }

    static let all: [EchoTrack] = [
        EchoTrack(name: "Save the World", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_000_stw_default/icon.png", url: "https://echo.rhysbot.com/musicpack_000.mp3"),
        EchoTrack(name: "Squeaky Clean", icon: "https://echo.rhysbot.com/musicpack_001_floss.png", url: "https://echo.rhysbot.com/musicpack_001.mp3"),
        EchoTrack(name: "Eerie", icon: "https://echo.rhysbot.com/musicpack_002_spooky.png", url: "https://echo.rhysbot.com/musicpack_002.mp3"),
        EchoTrack(name: "OG (Remix)", icon: "https://echo.rhysbot.com/musicpack_003_ogremix.png", url: "https://echo.rhysbot.com/musicpack_003.mp3"),
        EchoTrack(name: "Festive", icon: "https://echo.rhysbot.com/musicpack_004_holiday.png", url: "https://echo.rhysbot.com/musicpack_004.mp3"),
        EchoTrack(name: "Disco", icon: "https://echo.rhysbot.com/musicpack_005_disco.png", url: "https://echo.rhysbot.com/musicpack_005.mp3"),
        EchoTrack(name: "Twist", icon: "https://echo.rhysbot.com/musicpack_006_twist.png", url: "https://echo.rhysbot.com/musicpack_006.mp3"),
        EchoTrack(name: "Ahoy!", icon: "https://echo.rhysbot.com/musicpack_007_pirate.png", url: "https://echo.rhysbot.com/musicpack_007.mp3"),
        EchoTrack(name: "Coral Chorus", icon: "https://echo.rhysbot.com/musicpack_008_coral.png", url: "https://echo.rhysbot.com/musicpack_008.mp3"),
        EchoTrack(name: "Marathon", icon: "https://echo.rhysbot.com/musicpack_010_runningman.png", url: "https://echo.rhysbot.com/musicpack_010.mp3"),
        EchoTrack(name: "Get Funky", icon: "https://echo.rhysbot.com/musicpack_011_getfunky.png", url: "https://echo.rhysbot.com/musicpack_011.mp3"),
        EchoTrack(name: "Electro-fied!", icon: "https://echo.rhysbot.com/musicpack_012_electroswing.png", url: "https://echo.rhysbot.com/musicpack_012.mp3"),
        EchoTrack(name: "Afterburner", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_013_robotrack/icon.png", url: "https://echo.rhysbot.com/musicpack_013.mp3"),
        EchoTrack(name: "Neo World", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_014_s9cine/icon.png", url: "https://echo.rhysbot.com/musicpack_014.mp3"),
        EchoTrack(name: "Justice", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_015_goodvibes/icon.png", url: "https://echo.rhysbot.com/musicpack_015.mp3"),
        EchoTrack(name: "Winner's Circle", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_016_worldcup/icon.png", url: "https://echo.rhysbot.com/musicpack_016.mp3"),
        EchoTrack(name: "Saxy Groove", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_017_phoneitin/icon.png", url: "https://echo.rhysbot.com/musicpack_017.mp3"),
        EchoTrack(name: "Sparkles", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_018_glitter/icon.png", url: "https://echo.rhysbot.com/musicpack_018.mp3"),
        EchoTrack(name: "B-Day Beats", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_019_birthday2019/icon.png", url: "https://echo.rhysbot.com/musicpack_019.mp3"),
        EchoTrack(name: "Best Buds", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_020_bunkerjam/icon.png", url: "https://echo.rhysbot.com/musicpack_020.mp3"),
        EchoTrack(name: "Sweet Dreams", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_022_daydream/icon.png", url: "https://echo.rhysbot.com/musicpack_022.mp3"),
        EchoTrack(name: "OG (Classic)", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_023_og/icon.png", url: "https://echo.rhysbot.com/musicpack_023.mp3"),
        EchoTrack(name: "The Final Showdown", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_024_showdown/icon.png", url: "https://echo.rhysbot.com/musicpack_024.mp3"),
        EchoTrack(name: "Rainy Days", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_025_makeitrain/icon.png", url: "https://echo.rhysbot.com/musicpack_025.mp3"),
        EchoTrack(name: "Default Vibe", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_026_lasagnachill/icon.png", url: "https://echo.rhysbot.com/musicpack_026.mp3"),
        EchoTrack(name: "Llama Beat", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_028_llamabell/icon.png", url: "https://echo.rhysbot.com/musicpack_028.mp3"),
        EchoTrack(name: "Wiggle Wild", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_029_wiggle/icon.png", url: "https://echo.rhysbot.com/musicpack_029.mp3"),
        EchoTrack(name: "Caped Crusader", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_030_blackmonday_x91zh/icon.png", url: "https://echo.rhysbot.com/musicpack_030.mp3"),
        EchoTrack(name: "8-bit Beat", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_031_chiptune/icon.png", url: "https://echo.rhysbot.com/musicpack_031.mp3"),
        EchoTrack(name: "Solid Groove", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_032_groovejam/icon.png", url: "https://echo.rhysbot.com/musicpack_032.mp3"),
        EchoTrack(name: "The End", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_034_sxrocketevent/icon.png", url: "https://echo.rhysbot.com/musicpack_034.mp3"),
        EchoTrack(name: "Unreal Chill", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_039_envy/icon.png", url: "https://echo.rhysbot.com/musicpack_039.mp3"),
        EchoTrack(name: "Stand and Fight", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_stw001_cannyvalley/icon.png", url: "https://echo.rhysbot.com/musicpack_stw001.mp3"),
        EchoTrack(name: "Merry Chipmas", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_040_xmaschiptunes/icon.png", url: "https://echo.rhysbot.com/musicpack_040.mp3"),
        EchoTrack(name: "Mellow Days", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_041_slick/icon.png", url: "https://echo.rhysbot.com/musicpack_041.mp3"),
        EchoTrack(name: "OG (Future Remix)", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_053_fortnitetrapremix/icon.png", url: "https://echo.rhysbot.com/musicpack_053.mp3"),
        EchoTrack(name: "The Device", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_054_fritter/icon.png", url: "https://echo.rhysbot.com/musicpack_054.mp3"),
        EchoTrack(name: "Lobby Classic", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_119_ch1_defaultmusic/icon.png", url: "https://echo.rhysbot.com/musicpack_119.mp3"),
        EchoTrack(name: "Best Mates", icon: "https://fortnite-api.com/images/cosmetics/br/musicpack_123_bestmates/icon.png", url: "https://echo.rhysbot.com/musicpack_123.mp3"),
        EchoTrack(name: "Out of Time", icon: "https://echo.rhysbot.com/musicpack_999_outoftime.png", url: "https://echo.rhysbot.com/musicpack_999.mp3"),
        EchoTrack(name: "Forest", icon: "https://echo.rhysbot.com/musicpack_forest.png", url: "https://echo.rhysbot.com/musicpack_forest.mp3"),
        EchoTrack(name: "Ghost Town", icon: "https://echo.rhysbot.com/musicpack_canny.png", url: "https://echo.rhysbot.com/musicpack_canny.mp3"),
        EchoTrack(name: "Halloween 2016", icon: "https://echo.rhysbot.com/musicpack_halloween_2016.png", url: "https://echo.rhysbot.com/musicpack_halloween_2016.mp3"),
        EchoTrack(name: "Christmas 2017", icon: "https://echo.rhysbot.com/musicpack_christmas_2017.png", url: "https://echo.rhysbot.com/musicpack_christmas_2017.mp3"),
        EchoTrack(name: "Homebase", icon: "https://echo.rhysbot.com/musicpack_homebase.png", url: "https://echo.rhysbot.com/musicpack_homebase.mp3"),
    ]
}

@MainActor
final class EchoMusic: ObservableObject {
    private static let trackKey = "EchoMusicTrack"

    @Published private(set) var index: Int
    @Published private(set) var playing = false
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    init() {
        let saved = UserDefaults.standard.string(forKey: EchoMusic.trackKey) ?? ""
        index = EchoTrack.all.firstIndex { $0.name == saved } ?? 0
    }

    var track: EchoTrack { EchoTrack.all[index] }

    func toggle() {
        if playing {
            player?.pause()
            playing = false
        } else {
            start()
        }
    }

    func step(_ offset: Int) {
        let count = EchoTrack.all.count
        index = (index + offset + count) % count
        UserDefaults.standard.set(track.name, forKey: EchoMusic.trackKey)
        if playing { start() }
    }

    func select(_ track: EchoTrack) {
        index = EchoTrack.all.firstIndex { $0.id == track.id } ?? index
        UserDefaults.standard.set(track.name, forKey: EchoMusic.trackKey)
        start()
    }

    /// The game has its own audio, so the launcher's music stops when a game starts.
    func stop() {
        player?.pause()
        playing = false
    }

    private func start() {
        guard let url = URL(string: track.url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playing else { return }
                self.step(1)
            }
        }
        player = AVPlayer(playerItem: item)
        player?.play()
        playing = true
    }
}

struct EchoMusicPlayer: View {
    @ObservedObject var music: EchoMusic
    @State private var open = false
    @State private var listOpen = false

    var body: some View {
        HStack(spacing: 8) {
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    Text(music.track.name.uppercased()).font(EchoTheme.caps(13)).foregroundColor(.white).lineLimit(1)
                    Text(music.playing ? "Playing" : "Paused").font(EchoTheme.label(10)).foregroundColor(EchoTheme.dim)
                }
                .frame(width: 120, alignment: .leading)
                .onTapGesture { listOpen = true }
                EchoIconButton(icon: .previous, size: 34) { music.step(-1) }
                EchoIconButton(icon: music.playing ? .pause : .play, size: 34, active: true) { music.toggle() }
                EchoIconButton(icon: .next, size: 34) { music.step(1) }
            }
            Button(action: { withAnimation(.easeOut(duration: 0.3)) { open.toggle() } }) {
                EchoRemoteImage(url: URL(string: music.track.icon), icon: .music)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(5)
        .padding(.leading, open ? 10 : 0)
        .echoSurface(radius: 100)
        .sheet(isPresented: $listOpen) {
            EchoTrackList(music: music, open: $listOpen)
        }
    }
}

struct EchoTrackList: View {
    @ObservedObject var music: EchoMusic
    @Binding var open: Bool

    var body: some View {
        ZStack {
            EchoTheme.tint.opacity(0.55).background(Color.black).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MUSIC").font(EchoTheme.heading(36)).foregroundColor(.white)
                    ForEach(EchoTrack.all) { track in
                        Button(action: {
                            music.select(track)
                            open = false
                        }) {
                            HStack(spacing: 12) {
                                EchoRemoteImage(url: URL(string: track.icon), icon: .music)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius))
                                Text(track.name).font(EchoTheme.label(15, weight: 600)).foregroundColor(.white)
                                Spacer()
                                if track.id == music.track.id {
                                    EchoGlyph(icon: .check, size: 20).foregroundColor(EchoTheme.accent)
                                }
                            }
                            .padding(8)
                            .echoSurface()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}
