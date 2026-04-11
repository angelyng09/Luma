//
//  AuthEntryChoiceView.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import SwiftUI

struct AuthEntryChoiceView: View {
    let onSignIn: () -> Void
    let onCreateAccount: () -> Void
    @EnvironmentObject private var languageStore: LanguageStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("auth.entry.title"))
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                }
                .lumaCardStyle()

                languagePickerSection

                Button(action: onSignIn) {
                    Text(L10n.tr("auth.entry.button.sign_in"))
                }
                .buttonStyle(LumaPrimaryButtonStyle())

                Button(action: onCreateAccount) {
                    Text(L10n.tr("auth.entry.button.sign_up"))
                }
                .buttonStyle(LumaSecondaryButtonStyle())

                Spacer(minLength: 12)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("auth.entry.nav.title"))
        .inlineNavigationTitle()
        .onAppear {
            isTitleFocused = true
            AccessibilityAnnouncer.announce(L10n.tr("announcement.auth_entry_page"))
        }
        .onChange(of: languageStore.currentLanguage) { _, _ in
            AccessibilityAnnouncer.announce(L10n.tr("announcement.language_changed"))
        }
    }

    private var languagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("common.language"))
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.tr("auth.entry.language.description"))
                .font(.footnote)
                .foregroundStyle(LumaPalette.secondaryText)

            Picker(L10n.tr("common.language"), selection: $languageStore.currentLanguage) {
                Text(L10n.tr("common.language.english")).tag(AppLanguage.english)
                Text(L10n.tr("common.language.chinese")).tag(AppLanguage.chineseSimplified)
            }
            .pickerStyle(.segmented)
        }
        .lumaCardStyle()
    }
}
