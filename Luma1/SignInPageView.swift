//
//  SignInPageView.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import SwiftUI

struct SignInPageView: View {
    @ObservedObject var sessionStore: SessionStore
    let onCreateAccount: (() -> Void)?
    @StateObject private var speech = SpeechInputController()

    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var activeVoiceField: Field?
    @AccessibilityFocusState private var isTitleFocused: Bool

    private enum Field {
        case identifier
        case password
    }

    init(sessionStore: SessionStore, onCreateAccount: (() -> Void)? = nil) {
        self._sessionStore = ObservedObject(wrappedValue: sessionStore)
        self.onCreateAccount = onCreateAccount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("sign.in.title"))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                    Text(L10n.tr("login.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(LumaPalette.secondaryText)
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    textInputRow(
                        label: L10n.tr("auth.entry.field.identifier.label"),
                        placeholder: L10n.tr("auth.entry.field.identifier.placeholder"),
                        text: $identifier,
                        field: .identifier,
                        isSecure: false
                    )

                    textInputRow(
                        label: L10n.tr("auth.entry.field.password.label"),
                        placeholder: L10n.tr("auth.entry.field.password.placeholder"),
                        text: $password,
                        field: .password,
                        isSecure: true
                    )

                    if let speechError = speech.errorMessage {
                        Text(speechError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel(L10n.format("auth.entry.error.label", errorMessage))
                    }

                    Button {
                        submit()
                    } label: {
                        Text(isSubmitting ? L10n.tr("auth.entry.button.submitting") : L10n.tr("auth.entry.button.sign_in"))
                    }
                    .buttonStyle(LumaPrimaryButtonStyle())
                    .disabled(isSubmitting)

                    if let onCreateAccount {
                        Button(action: onCreateAccount) {
                            Text(L10n.tr("sign.in.link.create_account"))
                        }
                        .buttonStyle(LumaSecondaryButtonStyle())
                    }
                }
                .lumaCardStyle()
            }
            .padding(24)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("sign.in.nav.title"))
        .inlineNavigationTitle()
        .onAppear {
            isTitleFocused = true
            AccessibilityAnnouncer.announce(L10n.tr("announcement.sign_in_page"))
        }
    }

    @ViewBuilder
    private func textInputRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumaPalette.secondaryText)

            HStack(spacing: 8) {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .passwordInputBehavior()
                        .lumaInputStyle()
                        .accessibilityLabel(label)
                        .accessibilityHint(placeholder)
                } else {
                    TextField(placeholder, text: text)
                        .usernameInputBehavior()
                        .lumaInputStyle()
                        .accessibilityLabel(label)
                        .accessibilityHint(placeholder)
                }

                Button {
                    toggleVoiceInput(for: field)
                } label: {
                    Image(systemName: activeVoiceField == field && speech.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.title3)
                }
                .buttonStyle(LumaInlineIconButtonStyle())
                .accessibilityLabel("\(label), \(L10n.tr("speech.button.label"))")
                .accessibilityHint(L10n.tr("speech.button.hint"))
            }
        }
    }

    private func toggleVoiceInput(for field: Field) {
        if speech.isRecording {
            if activeVoiceField == field {
                speech.stopRecording()
                activeVoiceField = nil
                AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_stopped"))
                return
            }

            // Switching fields: stop and clear previous routing before starting new dictation.
            speech.stopRecording()
            activeVoiceField = nil
        }

        activeVoiceField = field
        AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_started"))
        speech.startRecording(
            onTranscript: { transcript in
                guard activeVoiceField == field else { return }
                guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                switch field {
                case .identifier:
                    identifier = transcript
                case .password:
                    password = transcript
                }
            },
            onStopped: { _ in
                if activeVoiceField == field {
                    activeVoiceField = nil
                }
            }
        )
    }

    private func submit() {
        guard isSubmitting == false else { return }

        if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let message = L10n.tr("auth.error.invalid_credentials")
            errorMessage = message
            AccessibilityAnnouncer.announce(message)
            return
        }

        isSubmitting = true
        errorMessage = nil
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await sessionStore.login(
                    identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                AccessibilityAnnouncer.announce(L10n.tr("announcement.sign_in_success"))
            } catch {
                let message = error.localizedDescription
                errorMessage = message
                AccessibilityAnnouncer.announce(L10n.format("announcement.auth_failed_with_message", message))
            }
        }
    }
}
