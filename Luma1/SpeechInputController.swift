//
//  SpeechInputController.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class SpeechInputController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var speechRecognizerLocaleIdentifier: String?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var onTranscript: ((String) -> Void)?
    private var onStopped: ((Bool) -> Void)?
    private var didCaptureTranscriptInSession = false
    private var activeSessionID: UInt64 = 0

    func startRecording(onTranscript: @escaping (String) -> Void, onStopped: ((Bool) -> Void)? = nil) {
        guard isRecording == false else { return }
        errorMessage = nil
        didCaptureTranscriptInSession = false
        self.onTranscript = onTranscript
        self.onStopped = onStopped
        activeSessionID &+= 1
        let sessionID = activeSessionID

        requestPermissions { [weak self] granted in
            guard let self else { return }
            if granted == false {
                self.errorMessage = L10n.tr("speech.error.permission")
                return
            }
            self.beginRecognition(sessionID: sessionID)
        }
    }

    func stopRecording() {
        let wasRecording = isRecording
        let capturedTranscript = didCaptureTranscriptInSession
        activeSessionID &+= 1
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        isRecording = false

        if wasRecording {
            onStopped?(capturedTranscript)
        }
        onTranscript = nil
        onStopped = nil
        didCaptureTranscriptInSession = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition(sessionID: UInt64) {
        guard let speechRecognizer = resolveSpeechRecognizer(), speechRecognizer.isAvailable else {
            errorMessage = L10n.tr("speech.error.unavailable")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Keep VoiceOver and other assistive audio intelligible while dictation is active.
            try audioSession.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let audioEngine = AVAudioEngine()
            self.audioEngine = audioEngine

            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
                errorMessage = L10n.tr("speech.error.unavailable")
                stopRecording()
                return
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let localizedError = error?.localizedDescription

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.activeSessionID == sessionID else { return }
                    if let transcript {
                        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedTranscript.isEmpty == false {
                            self.onTranscript?(transcript)
                            self.didCaptureTranscriptInSession = true
                        }
                        if isFinal {
                            self.stopRecording()
                        }
                    }
                    if let localizedError {
                        self.errorMessage = localizedError
                        self.stopRecording()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopRecording()
        }
    }

    private func resolveSpeechRecognizer() -> SFSpeechRecognizer? {
        let targetLocale = preferredRecognitionLocale()

        if
            let speechRecognizer,
            speechRecognizerLocaleIdentifier == targetLocale.identifier
        {
            return speechRecognizer
        }

        let resolved = SFSpeechRecognizer(locale: targetLocale)
        speechRecognizer = resolved
        speechRecognizerLocaleIdentifier = targetLocale.identifier
        return resolved
    }

    private func preferredRecognitionLocale() -> Locale {
        // Product requirement: always recognize Chinese speech, independent of app/system language.
        return Locale(identifier: "zh-CN")
    }

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    completion(
                        speechStatus == .authorized && micGranted
                    )
                }
            }
        }
    }
}
