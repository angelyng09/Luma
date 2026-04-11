//
//  SettingsPageView.swift
//  Luma
//
//  Created by Codex on 3/20/26.
//

import SwiftUI

struct SettingsPageView: View {
    @ObservedObject var sessionStore: SessionStore
    @EnvironmentObject private var languageStore: LanguageStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    @State private var currentUsername = ""
    @State private var currentEmail = ""
    @State private var usernameDraft = ""
    @State private var passwordDraft = ""

    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isSavingUsername = false
    @State private var isSavingPassword = false
    @State private var isDeletingAccount = false
    @State private var showDeleteConfirmation = false

    private var currentRoleTitle: String {
        sessionStore.currentRole?.title ?? L10n.tr("home.role.unknown")
    }

    private var hasActiveAccount: Bool {
        currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var isSaving: Bool {
        isSavingUsername || isSavingPassword || isDeletingAccount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.tr("settings.title"))
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                    .lumaCardStyle()

                summarySection
                preferencesSection
                actionsSection
                deleteSection

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel(errorMessage)
                }
            }
            .padding(24)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("settings.nav.title"))
        .inlineNavigationTitle()
        .disabled(isSaving)
        .alert(L10n.tr("settings.delete.confirm.title"), isPresented: $showDeleteConfirmation) {
            Button(L10n.tr("settings.delete.confirm.cancel"), role: .cancel) {}
            Button(L10n.tr("settings.delete.confirm.delete"), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(L10n.tr("settings.delete.confirm.message"))
        }
        .onAppear {
            isTitleFocused = true
            loadProfile()
            AccessibilityAnnouncer.announce(L10n.tr("announcement.settings_page"))
        }
        .onChange(of: languageStore.currentLanguage) { _, _ in
            AccessibilityAnnouncer.announce(L10n.tr("announcement.language_changed"))
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.section.account_summary"))
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)

            summaryRow(label: L10n.tr("settings.field.current_role"), value: currentRoleTitle)
            summaryRow(
                label: L10n.tr("settings.field.current_username"),
                value: hasActiveAccount ? currentUsername : L10n.tr("settings.value.not_available")
            )

            if hasActiveAccount {
                summaryRow(label: L10n.tr("settings.field.current_email"), value: currentEmail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumaCardStyle()
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.section.account_actions"))
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)

            Text(L10n.tr("settings.action.change_username"))
                .font(.subheadline.weight(.semibold))

            TextField(L10n.tr("settings.input.username.placeholder"), text: $usernameDraft)
                .textInputAutocapitalization(.never)
                .lumaInputStyle()
                .disabled(hasActiveAccount == false)
                .accessibilityLabel(L10n.tr("settings.action.change_username"))
                .accessibilityHint(L10n.tr("settings.input.username.placeholder"))

            Button {
                saveUsername()
            } label: {
                Text(isSavingUsername ? L10n.tr("settings.button.saving") : L10n.tr("settings.button.save_username"))
            }
            .buttonStyle(LumaSecondaryButtonStyle())
            .disabled(isSaving || hasActiveAccount == false)

            Divider()

            Text(L10n.tr("settings.action.change_password"))
                .font(.subheadline.weight(.semibold))

            SecureField(L10n.tr("settings.input.password.placeholder"), text: $passwordDraft)
                .passwordInputBehavior()
                .lumaInputStyle()
                .disabled(hasActiveAccount == false)
                .accessibilityLabel(L10n.tr("settings.action.change_password"))
                .accessibilityHint(L10n.tr("settings.input.password.placeholder"))

            Button {
                savePassword()
            } label: {
                Text(isSavingPassword ? L10n.tr("settings.button.saving") : L10n.tr("settings.button.save_password"))
            }
            .buttonStyle(LumaSecondaryButtonStyle())
            .disabled(isSaving || hasActiveAccount == false)
        }
        .lumaCardStyle()
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.section.preferences"))
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)

            Text(L10n.tr("settings.language.description"))
                .font(.footnote)
                .foregroundStyle(LumaPalette.secondaryText)

            Picker(L10n.tr("common.language"), selection: $languageStore.currentLanguage) {
                Text(L10n.tr("common.language.english")).tag(AppLanguage.english)
                Text(L10n.tr("common.language.chinese")).tag(AppLanguage.chineseSimplified)
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumaCardStyle()
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(role: .destructive) {
                AccessibilityAnnouncer.announce(L10n.tr("announcement.settings_delete_confirm"))
                showDeleteConfirmation = true
            } label: {
                Text(L10n.tr("settings.action.delete_account"))
            }
            .buttonStyle(LumaSecondaryButtonStyle())
            .disabled(isSaving || hasActiveAccount == false)
        }
        .lumaCardStyle()
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(LumaPalette.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func loadProfile() {
        guard let profile = sessionStore.currentAccountProfile() else {
            currentUsername = ""
            currentEmail = ""
            usernameDraft = ""
            return
        }

        currentUsername = profile.username
        currentEmail = profile.email
        usernameDraft = profile.username
    }

    private func saveUsername() {
        guard hasActiveAccount else {
            showNoAccountError()
            return
        }

        let trimmed = usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            let message = L10n.tr("auth.error.invalid_username")
            errorMessage = message
            statusMessage = nil
            AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
            return
        }

        errorMessage = nil
        statusMessage = nil
        isSavingUsername = true

        Task { @MainActor in
            defer { isSavingUsername = false }
            do {
                let profile = try await sessionStore.updateCurrentUsername(trimmed)
                currentUsername = profile.username
                usernameDraft = profile.username
                statusMessage = L10n.tr("settings.message.username_updated")
                errorMessage = nil
                AccessibilityAnnouncer.announce(L10n.tr("announcement.settings_updated"))
            } catch {
                let message = error.localizedDescription
                errorMessage = L10n.format("settings.message.save_failed", message)
                statusMessage = nil
                AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
            }
        }
    }

    private func savePassword() {
        guard hasActiveAccount else {
            showNoAccountError()
            return
        }

        let trimmed = passwordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            let message = L10n.tr("auth.error.weak_password")
            errorMessage = message
            statusMessage = nil
            AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
            return
        }

        errorMessage = nil
        statusMessage = nil
        isSavingPassword = true

        Task { @MainActor in
            defer { isSavingPassword = false }
            do {
                try await sessionStore.updateCurrentPassword(trimmed)
                passwordDraft = ""
                statusMessage = L10n.tr("settings.message.password_updated")
                errorMessage = nil
                AccessibilityAnnouncer.announce(L10n.tr("announcement.settings_updated"))
            } catch {
                let message = error.localizedDescription
                errorMessage = L10n.format("settings.message.save_failed", message)
                statusMessage = nil
                AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
            }
        }
    }

    private func deleteAccount() {
        guard hasActiveAccount else {
            showNoAccountError()
            return
        }

        errorMessage = nil
        statusMessage = nil
        isDeletingAccount = true

        Task { @MainActor in
            defer { isDeletingAccount = false }
            do {
                try await sessionStore.deleteCurrentAccount()
                AccessibilityAnnouncer.announce(L10n.tr("announcement.settings_delete_success"))
            } catch {
                let message = error.localizedDescription
                errorMessage = L10n.format("settings.message.save_failed", message)
                statusMessage = nil
                AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
            }
        }
    }

    private func showNoAccountError() {
        let message = L10n.tr("auth.error.no_active_account")
        errorMessage = message
        statusMessage = nil
        AccessibilityAnnouncer.announce(L10n.format("announcement.settings_update_failed_with_message", message))
    }
}
