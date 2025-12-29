//
//  WakeWordService.swift
//  Pod AI
//
//  Handles wake word detection using Porcupine
//

import Foundation
import AVFoundation
import Porcupine
import SwiftUI
import Combine

enum WakeWordState: Equatable, Sendable {
    case inactive
    case listening
    case detected
    case error(String)
}

final class WakeWordService: ObservableObject, @unchecked Sendable {
    @MainActor @Published var state: WakeWordState = .inactive
    @MainActor @Published var isEnabled: Bool = false

    private var porcupineManager: PorcupineManager?
    private var onWakeWordDetected: (() -> Void)?

    init() {}

    // MARK: - Public API

    @MainActor
    func startListening(onDetected: @escaping () -> Void) {
        self.onWakeWordDetected = onDetected

        guard let accessKey = SecretsManager.picovoiceAccessKey else {
            state = .error("Picovoice access key not configured")
            print("⚠️ Wake word error: No Picovoice access key in Secrets.plist")
            return
        }

        do {
            // Try custom "pod" wake word first, fall back to built-in for testing
            if let customKeywordPath = Bundle.main.path(forResource: "pod_ios", ofType: "ppn") {
                // Use custom "pod" wake word
                porcupineManager = try PorcupineManager(
                    accessKey: accessKey,
                    keywordPaths: [customKeywordPath],
                    sensitivities: [0.7],
                    onDetection: { [weak self] keywordIndex in
                        self?.handleDetection(keywordIndex: keywordIndex)
                    }
                )
                print("✅ Using custom 'pod' wake word")
            } else {
                // Fall back to built-in keyword for testing
                porcupineManager = try PorcupineManager(
                    accessKey: accessKey,
                    keyword: .computer,  // Use "Computer" as fallback for testing
                    onDetection: { [weak self] keywordIndex in
                        self?.handleDetection(keywordIndex: keywordIndex)
                    }
                )
                print("⚠️ Using built-in 'Computer' wake word (custom 'pod' not found)")
            }

            try porcupineManager?.start()
            state = .listening
            isEnabled = true
            print("✅ Wake word detection started")

        } catch {
            state = .error(error.localizedDescription)
            print("❌ Wake word error: \(error)")
        }
    }

    @MainActor
    func stopListening() {
        try? porcupineManager?.stop()
        porcupineManager = nil
        state = .inactive
        isEnabled = false
        print("🛑 Wake word detection stopped")
    }

    @MainActor
    func pauseListening() {
        try? porcupineManager?.stop()
        state = .inactive
        print("⏸️ Wake word detection paused")
    }

    @MainActor
    func resumeListening() {
        guard isEnabled else { return }
        do {
            try porcupineManager?.start()
            state = .listening
            print("▶️ Wake word detection resumed")
        } catch {
            state = .error(error.localizedDescription)
            print("❌ Wake word resume error: \(error)")
        }
    }

    // MARK: - Private

    private func handleDetection(keywordIndex: Int32) {
        guard keywordIndex >= 0 else { return }

        print("🎤 [WAKE WORD] Detection triggered! keywordIndex=\(keywordIndex), currentState=\(state)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                print("🎤 [WAKE WORD] Setting state to .detected, calling onWakeWordDetected")
                self.state = .detected
                self.onWakeWordDetected?()

                // Reset to listening after a short delay
                try? await Task.sleep(for: .milliseconds(500))
                if self.state == .detected {
                    print("🎤 [WAKE WORD] Resetting state to .listening")
                    self.state = .listening
                }
            }
        }
    }
}
