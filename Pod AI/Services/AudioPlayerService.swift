//
//  AudioPlayerService.swift
//  Pod AI
//

import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerService: ObservableObject {
    @Published var currentEpisode: Episode?
    @Published var currentPodcast: Podcast?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var currentTranscript: String = ""
    @Published var isLoadingTranscript = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let transcriptService = TranscriptService()
    private var routeChangeObserver: NSObjectProtocol?

    init() {
        setupRouteChangeObserver()
        setupAudioSession()
        setupRemoteCommands()
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Audio Route Debugging

    private func setupRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let reasonString: String
        switch reason {
        case .newDeviceAvailable: reasonString = "🔌 New device available"
        case .oldDeviceUnavailable: reasonString = "🔌 Old device unavailable"
        case .categoryChange: reasonString = "🔄 Category changed"
        case .override: reasonString = "⚡ Override"
        case .wakeFromSleep: reasonString = "😴 Wake from sleep"
        case .noSuitableRouteForCategory: reasonString = "❌ No suitable route"
        case .routeConfigurationChange: reasonString = "🔧 Route config changed"
        default: reasonString = "❓ Unknown reason (\(reasonValue))"
        }

        print("🔊 [ROUTE CHANGE] \(reasonString)")
        logCurrentRoute(context: "after route change")
    }

    private func logCurrentRoute(context: String) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute

        print("📍 [AUDIO ROUTE] --- \(context) ---")
        print("   Category: \(session.category.rawValue)")
        print("   Mode: \(session.mode.rawValue)")
        print("   Options: \(session.categoryOptions)")

        print("   OUTPUTS:")
        for output in route.outputs {
            print("      → \(output.portType.rawValue) - \"\(output.portName)\"")
        }

        print("   INPUTS:")
        for input in route.inputs {
            print("      ← \(input.portType.rawValue) - \"\(input.portName)\"")
        }
        print("📍 [AUDIO ROUTE] --- end ---")
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            // Use playAndRecord to allow wake word detection while playing podcasts
            // - videoChat mode: Less aggressive volume reduction than voiceChat/default
            // - defaultToSpeaker: Audio plays through main speaker (not earpiece)
            // - allowBluetoothA2DP: High quality Bluetooth audio
            // - allowAirPlay: Support AirPlay speakers
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowAirPlay]
            )
            logCurrentRoute(context: "after setCategory")

            try session.setActive(true)
            logCurrentRoute(context: "after setActive")

            try session.overrideOutputAudioPort(.speaker)
            logCurrentRoute(context: "after overrideOutputAudioPort(.speaker)")

        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Playback Controls

    func play(episode: Episode, from podcast: Podcast? = nil) {
        // Clean up previous player
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        currentEpisode = episode
        currentPodcast = podcast
        currentTranscript = ""
        isLoading = true

        let playerItem = AVPlayerItem(url: episode.audioURL)
        player = AVPlayer(playerItem: playerItem)

        // Observe when ready to play
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.isLoading = false
                    self?.duration = playerItem.duration.seconds.isNaN ? episode.duration : playerItem.duration.seconds
                    self?.logCurrentRoute(context: "before play()")
                    self?.player?.play()
                    self?.isPlaying = true
                    self?.updateNowPlayingInfo()
                    self?.logCurrentRoute(context: "after play()")
                }
            }
            .store(in: &cancellables)

        // Time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
            self?.updateNowPlayingInfo()
        }

        // Load transcript in background
        loadTranscript(for: episode)
    }

    private func loadTranscript(for episode: Episode) {
        isLoadingTranscript = true
        Task {
            let transcript = await transcriptService.getTranscript(for: episode)
            await MainActor.run {
                self.currentTranscript = transcript ?? ""
                self.isLoadingTranscript = false
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
        updateNowPlayingInfo()
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    // MARK: - Remote Commands (Lock Screen / Control Center)

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else { return }

        let podcastName = currentPodcast?.title ?? "Podcast"

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: podcastName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Formatting

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedRemainingTime: String {
        let remaining = duration - currentTime
        return "-" + formatTime(remaining)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
