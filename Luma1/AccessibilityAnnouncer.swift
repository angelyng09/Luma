//
//  AccessibilityAnnouncer.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

enum AccessibilityAnnouncer {
    #if canImport(UIKit)
    private static var lastAnnouncementMessage = ""
    private static var lastAnnouncementAt = Date.distantPast

    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    #else
    static var isVoiceOverRunning: Bool {
        false
    }
    #endif

    static func announce(_ message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(UIKit)
        guard trimmedMessage.isEmpty == false else { return }
        guard UIAccessibility.isVoiceOverRunning else { return }

        let now = Date()
        if trimmedMessage == lastAnnouncementMessage, now.timeIntervalSince(lastAnnouncementAt) < 0.6 {
            return
        }
        lastAnnouncementMessage = trimmedMessage
        lastAnnouncementAt = now

        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: trimmedMessage)
        }
        #else
        _ = trimmedMessage
        #endif
    }

    static func moveVoiceOverFocus(to argument: Any?) {
        #if canImport(UIKit)
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: argument)
        }
        #else
        _ = argument
        #endif
    }
}

#if canImport(AVFoundation)
@MainActor
final class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false

    private static let preferenceStorageKey = "luma.speech.saved_preferences"
    private let synthesizer = AVSpeechSynthesizer()

    var savedPreferences: [String] {
        let values = UserDefaults.standard.stringArray(forKey: Self.preferenceStorageKey) ?? []
        return values.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: AppLanguage? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        configureAudioSessionForSpokenPlayback()
        stop()

        let utterance = AVSpeechUtterance(string: trimmed)
        let resolvedLanguage = resolveSpeechLanguage(from: language)
        utterance.voice = AVSpeechSynthesisVoice(language: resolvedLanguage)
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func rememberPreferences(from question: String) {
        let terms = extractPreferenceTerms(from: question)
        guard terms.isEmpty == false else { return }

        var merged = savedPreferences
        for term in terms where merged.contains(term) == false {
            merged.append(term)
        }
        UserDefaults.standard.set(merged, forKey: Self.preferenceStorageKey)
    }

    private func extractPreferenceTerms(from question: String) -> [String] {
        let normalized = question.lowercased()
        let termMap: [(String, [String])] = [
            ("entrance access", ["entrance", "entry", "door", "ramp", "入口", "坡道"]),
            ("route clarity", ["route", "path", "wayfinding", "路线", "指引"]),
            ("vertical mobility", ["elevator", "lift", "stairs", "电梯", "楼梯"]),
            ("restroom access", ["restroom", "toilet", "bathroom", "卫生间", "厕所"]),
            ("staff support", ["staff", "help", "assistance", "工作人员", "帮助"]),
            ("crowd level", ["crowd", "queue", "line", "拥挤", "排队"]),
            ("quiet environment", ["quiet", "noise", "loud", "安静", "噪音"]),
        ]

        return termMap.compactMap { label, keywords in
            keywords.contains(where: { normalized.contains($0) }) ? label : nil
        }
    }

    private func resolveSpeechLanguage(from override: AppLanguage?) -> String {
        let chosen = override
            ?? AppLanguage.resolve(from: UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey))
            ?? AppLanguage.deviceDefault
        switch chosen {
        case .english:
            return "en-US"
        case .chineseSimplified:
            return "zh-CN"
        }
    }

    private func configureAudioSessionForSpokenPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Keep synthesis attempt alive even if the session cannot be reconfigured.
        }
    }

}

extension SpeechManager {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
#endif
