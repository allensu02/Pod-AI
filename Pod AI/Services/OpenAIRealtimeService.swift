//
//  OpenAIRealtimeService.swift
//  Pod AI
//
//  Handles WebSocket connection to OpenAI Realtime API for voice interaction
//

import Foundation
import AVFoundation
import Combine

enum RealtimeConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }
}

enum RealtimeVoiceState {
    case idle
    case listening
    case processing
    case speaking
}

class OpenAIRealtimeService: NSObject, ObservableObject {
    @Published var connectionState: RealtimeConnectionState = .disconnected
    @Published var voiceState: RealtimeVoiceState = .idle
    @Published var transcribedText: String = ""
    @Published var responseText: String = ""

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioConverter: AVAudioConverter?
    private var configurationObserver: NSObjectProtocol?

    private var currentTranscript: String = ""
    private var currentPodcastName: String = ""
    private var onResponseComplete: (() -> Void)?
    var onFunctionCall: ((String, [String: Any]) -> Void)?

    private let realtimeURL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17"

    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    deinit {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    func connect(withTranscript transcript: String, podcastName: String = "Podcast") {
        currentTranscript = transcript
        currentPodcastName = podcastName
        connectionState = .connecting

        guard let url = URL(string: realtimeURL) else {
            connectionState = .error("Invalid URL")
            return
        }

        let apiKey = SecretsManager.openAIAPIKey
        print("🔌 [DEBUG] Connecting to Realtime API...")
        print("🔑 [DEBUG] API Key prefix: \(String(apiKey.prefix(10)))...")
        print("🎙️ [DEBUG] Podcast: \(podcastName)")
        print("🌐 [DEBUG] URL: \(realtimeURL)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        webSocket = urlSession.webSocketTask(with: request)
        webSocket?.resume()

        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        voiceState = .idle
        teardownAudioEngine()
    }

    func startListening(onResponseComplete: @escaping () -> Void) {
        self.onResponseComplete = onResponseComplete
        self.responseComplete = false
        self.hasCalledCompletion = false
        voiceState = .listening
        startAudioCapture()
    }

    func stopListening() {
        voiceState = .processing
        stopAudioCapture()
        sendInputAudioBufferCommit()
    }

    // MARK: - Session Configuration

    private func configureSession() {
        let tools: [[String: Any]] = [
            [
                "type": "function",
                "name": "resume_podcast",
                "description": "Resume podcast playback and close the voice assistant. Call this when the user wants to go back to listening, continue the episode, or is done asking questions.",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any]
                ]
            ],
            [
                "type": "function",
                "name": "skip_forward",
                "description": "Skip forward in the podcast by a specified number of seconds.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "seconds": [
                            "type": "integer",
                            "description": "Number of seconds to skip forward. Defaults to 30 if not specified."
                        ]
                    ]
                ]
            ],
            [
                "type": "function",
                "name": "skip_backward",
                "description": "Skip backward in the podcast by a specified number of seconds.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "seconds": [
                            "type": "integer",
                            "description": "Number of seconds to skip backward. Defaults to 15 if not specified."
                        ]
                    ]
                ]
            ]
        ]

        // Limit transcript to ~8000 chars to avoid API issues with very long instructions
        let maxTranscriptLength = 8000
        let transcriptContext: String
        if currentTranscript.isEmpty {
            transcriptContext = "No transcript available for this episode."
        } else if currentTranscript.count > maxTranscriptLength {
            let truncated = String(currentTranscript.prefix(maxTranscriptLength))
            transcriptContext = truncated + "\n\n[Transcript truncated for length...]"
            print("⚠️ [DEBUG] Transcript truncated from \(currentTranscript.count) to \(maxTranscriptLength) chars")
        } else {
            transcriptContext = currentTranscript
        }

        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": """
                    You are a helpful AI assistant for the "\(currentPodcastName)" podcast.

                    TRANSCRIPT:
                    \(transcriptContext)

                    RULES:
                    - Be extremely concise: 1-2 sentences max
                    - No filler phrases ("Great question", "Let me explain", "I'd be happy to")
                    - Answer directly, then ask "Any other questions?"
                    - If transcript is unavailable or question not covered, say "I don't have that information for this episode"
                    - If user says "no", "nope", "I'm good", "that's it" → call resume_podcast immediately

                    FUNCTIONS - use immediately when triggered:
                    - resume_podcast: "go back", "resume", "done", "no", "nope", "I'm good", "that's it" → call without speaking
                    - skip_forward/skip_backward: "skip", "rewind", "go back X seconds" → call without speaking
                    """,
                "voice": "alloy",
                "speed": 1.5,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 100,
                    "silence_duration_ms": 300
                ],
                "tools": tools
            ]
        ]

        print("📤 [DEBUG] Sending session config with modalities: text, audio")
        sendJSON(sessionConfig)
    }

    // MARK: - WebSocket Messages

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func sendInputAudioBufferCommit() {
        sendJSON(["type": "input_audio_buffer.commit"])
        sendJSON(["type": "response.create"])
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()
            case .failure(let error):
                print("❌ [DEBUG] WebSocket receive error: \(error)")
                print("❌ [DEBUG] Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
                DispatchQueue.main.async {
                    self?.connectionState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }

            handleEvent(type: type, json: json)

        case .data(let data):
            print("Received binary data: \(data.count) bytes")

        @unknown default:
            break
        }
    }

    private func handleEvent(type: String, json: [String: Any]) {
        print("📨 [DEBUG] Received event: \(type)")
        DispatchQueue.main.async { [weak self] in
            switch type {
            case "session.created":
                print("✅ [DEBUG] Session created successfully!")
                self?.connectionState = .connected
                self?.configureSession()

            case "session.updated":
                print("✅ [DEBUG] Session updated!")
                if let session = json["session"] as? [String: Any] {
                    print("📋 [DEBUG] Modalities: \(session["modalities"] ?? "unknown")")
                    print("📋 [DEBUG] Voice: \(session["voice"] ?? "unknown")")
                    print("📋 [DEBUG] Output format: \(session["output_audio_format"] ?? "unknown")")
                    print("📋 [DEBUG] Full session: \(session)")
                }

            case "input_audio_buffer.speech_started":
                // User started speaking - stop any current AI audio (interruption)
                self?.stopPlayback()
                self?.voiceState = .listening

            case "input_audio_buffer.speech_stopped":
                self?.voiceState = .processing

            case "conversation.item.input_audio_transcription.completed":
                if let transcript = json["transcript"] as? String {
                    self?.transcribedText = transcript
                }

            case "response.audio.delta":
                print("🔊 [DEBUG] Received audio delta!")
                self?.voiceState = .speaking
                if let delta = json["delta"] as? String,
                   let audioData = Data(base64Encoded: delta) {
                    print("🔊 [DEBUG] Playing audio chunk: \(audioData.count) bytes")
                    self?.playAudio(audioData)
                }

            case "response.audio_transcript.delta":
                if let delta = json["delta"] as? String {
                    self?.responseText += delta
                }

            // Function calling events
            case "response.output_item.added":
                // Check if this is a function call
                if let item = json["item"] as? [String: Any],
                   let type = item["type"] as? String,
                   type == "function_call",
                   let name = item["name"] as? String {
                    self?.currentFunctionName = name
                    self?.currentFunctionArgs = ""
                }

            case "response.function_call_arguments.delta":
                if let delta = json["delta"] as? String {
                    self?.currentFunctionArgs += delta
                }

            case "response.function_call_arguments.done":
                if let name = self?.currentFunctionName, !name.isEmpty {
                    // Parse arguments
                    var args: [String: Any] = [:]
                    if let argsString = self?.currentFunctionArgs,
                       let argsData = argsString.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                        args = parsed
                    }

                    // Call the function handler
                    self?.onFunctionCall?(name, args)

                    // Reset
                    self?.currentFunctionName = ""
                    self?.currentFunctionArgs = ""
                }

            case "response.done":
                self?.responseText = ""
                self?.responseComplete = true
                // Only go to idle and call completion if audio is done playing
                if self?.isPlayingAudio == false && self?.hasCalledCompletion == false {
                    self?.hasCalledCompletion = true
                    self?.voiceState = .idle
                    self?.onResponseComplete?()
                }

            case "error":
                if let error = json["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "Unknown error"
                    let code = error["code"] as? String ?? "no code"
                    print("❌ [DEBUG] Realtime API ERROR: \(message) (code: \(code))")
                    print("❌ [DEBUG] Full error: \(error)")
                    self?.connectionState = .error(message)
                }

            default:
                break
            }
        }
    }

    // MARK: - Audio Engine Setup (Single engine for both input and output)

    private func setupAudioEngine() {
        // Only set up once
        guard audioEngine == nil else { return }

        // Configure audio session for simultaneous recording and playback
        do {
            let session = AVAudioSession.sharedInstance()

            print("🎙️ [DEBUG] Current audio session category: \(session.category.rawValue)")
            print("🎙️ [DEBUG] Switching to playAndRecord mode...")

            // First deactivate, then set category, then reactivate
            // This helps iOS properly transition between audio modes
            try session.setActive(false, options: .notifyOthersOnDeactivation)



            print("🎙️ [DEBUG] Audio session configured successfully")
        } catch {
            print("❌ [DEBUG] Audio session setup error: \(error)")
            return
        }

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        // Enable voice processing (echo cancellation) on input node
        let inputNode = engine.inputNode
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("Failed to enable voice processing: \(error)")
        }

        // Set up player node on the SAME engine for output
        let player = AVAudioPlayerNode()
        engine.attach(player)

        // Connect player to main mixer (required path to output)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        audioPlayer = player

        // Observe configuration changes (engine may restart when voice processing enables)
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            if self?.audioEngine?.isRunning == false {
                try? self?.audioEngine?.start()
            }
        }

        // Start the engine
        do {
            try engine.start()
        } catch {
            print("Audio engine start error: \(error)")
        }
    }

    private func startAudioCapture() {
        print("🎤 [DEBUG] Starting audio capture...")

        // Ensure engine is set up
        setupAudioEngine()

        guard let engine = audioEngine else {
            print("❌ [DEBUG] Audio engine is nil!")
            return
        }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        print("🎤 [DEBUG] Hardware format: \(hardwareFormat)")
        print("🎤 [DEBUG] Sample rate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")

        // Check for valid format
        guard hardwareFormat.sampleRate > 0 else {
            print("❌ [DEBUG] Invalid hardware format - sample rate is 0")
            return
        }

        // Target format: PCM 16-bit, 24kHz, mono
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true) else {
            print("❌ [DEBUG] Failed to create output format")
            return
        }

        audioConverter = AVAudioConverter(from: hardwareFormat, to: outputFormat)
        print("🎤 [DEBUG] Audio converter created: \(audioConverter != nil)")

        // Install tap to capture mic input
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: self?.audioConverter, outputFormat: outputFormat)
        }
        print("🎤 [DEBUG] Audio tap installed, listening for input...")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, outputFormat: AVAudioFormat) {
        guard let converter = converter else { return }

        let frameCount = AVAudioFrameCount(outputFormat.sampleRate * Double(buffer.frameLength) / buffer.format.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, let int16Data = outputBuffer.int16ChannelData else { return }

        let data = Data(bytes: int16Data[0], count: Int(outputBuffer.frameLength) * 2)
        let base64 = data.base64EncodedString()

        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": base64
        ])
    }

    private func stopAudioCapture() {
        // Just remove the tap, keep the engine running for playback
        audioEngine?.inputNode.removeTap(onBus: 0)
    }

    // MARK: - Audio Playback

    private var audioOutputBuffer = Data()
    private var isPlayingAudio = false
    private var responseComplete = false
    private var hasCalledCompletion = false
    private var currentFunctionName: String = ""
    private var currentFunctionArgs: String = ""

    private func playAudio(_ data: Data) {
        audioOutputBuffer.append(data)

        if !isPlayingAudio {
            isPlayingAudio = true
            playNextChunk()
        }
    }

    private func playNextChunk() {
        guard audioOutputBuffer.count >= 4800 else {
            isPlayingAudio = false
            // If response is complete and audio finished, notify completion (only once)
            if responseComplete && !hasCalledCompletion {
                hasCalledCompletion = true
                voiceState = .idle
                onResponseComplete?()
                responseComplete = false
            }
            return
        }

        let chunkSize = min(4800, audioOutputBuffer.count)
        let chunk = audioOutputBuffer.prefix(chunkSize)
        audioOutputBuffer.removeFirst(chunkSize)

        // Convert PCM16 data to playable audio
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        let frameCount = UInt32(chunk.count / 2)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            playNextChunk()
            return
        }

        buffer.frameLength = frameCount
        chunk.withUnsafeBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                memcpy(buffer.int16ChannelData![0], baseAddress, chunk.count)
            }
        }

        // Ensure engine and player are set up
        if audioPlayer == nil {
            setupAudioEngine()
        }

        audioPlayer?.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                self?.playNextChunk()
            }
        }

        if !(audioPlayer?.isPlaying ?? false) {
            audioPlayer?.play()
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioOutputBuffer.removeAll()
        isPlayingAudio = false
        // Don't destroy the engine - keep it for future use
    }

    private func teardownAudioEngine() {
        audioPlayer?.stop()
        audioEngine?.stop()
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationObserver = nil
        }
        audioPlayer = nil
        audioEngine = nil
        audioOutputBuffer.removeAll()
        isPlayingAudio = false
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OpenAIRealtimeService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [DEBUG] WebSocket OPENED successfully")
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "no reason"
        print("❌ [DEBUG] WebSocket CLOSED - code: \(closeCode.rawValue), reason: \(reasonString)")
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.voiceState = .idle
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ [DEBUG] WebSocket connection FAILED: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("❌ [DEBUG] URLError code: \(urlError.code.rawValue)")
            }
            DispatchQueue.main.async {
                self.connectionState = .error(error.localizedDescription)
            }
        }
    }
}
