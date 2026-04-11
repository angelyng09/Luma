//
//  AuthViewModel.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    func submit(with sessionStore: SessionStore) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await sessionStore.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            AccessibilityAnnouncer.announce(L10n.tr("announcement.login_success"))
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            AccessibilityAnnouncer.announce(L10n.format("announcement.login_failed_with_message", message))
        }
    }
}

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var agreedToTerms = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    func submit(with sessionStore: SessionStore) async {
        errorMessage = nil
        guard agreedToTerms else {
            let message = L10n.tr("auth.validation.agree_terms")
            errorMessage = message
            AccessibilityAnnouncer.announce(message)
            return
        }
        guard password == confirmPassword else {
            let message = L10n.tr("auth.validation.password_mismatch")
            errorMessage = message
            AccessibilityAnnouncer.announce(message)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await sessionStore.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            AccessibilityAnnouncer.announce(L10n.tr("announcement.register_success"))
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            AccessibilityAnnouncer.announce(L10n.format("announcement.register_failed_with_message", message))
        }
    }
}
