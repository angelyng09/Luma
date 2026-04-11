//
//  RoleSelectionView.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var selectedRole: AppRole?
    @State private var localError: String?
    @State private var isSaving = false

    private var isSwitchMode: Bool {
        sessionStore.isRoleSwitching && sessionStore.currentRole != nil
    }

    private var canContinue: Bool {
        selectedRole != nil && isSaving == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("login.title"))
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilitySortPriority(100)

                    Text(L10n.tr("login.subtitle"))
                        .foregroundStyle(LumaPalette.secondaryText)
                        .accessibilitySortPriority(95)
                }
                .lumaCardStyle()

                ForEach(Array(AppRole.allCases.enumerated()), id: \.element.rawValue) { index, role in
                    roleCard(role, order: index)
                }

                if let selectedRole {
                    Text(L10n.format("login.helper.continuing", selectedRole.title))
                        .font(.footnote)
                        .foregroundStyle(LumaPalette.secondaryText)
                        .accessibilitySortPriority(30)
                        .padding(.horizontal, 2)
                }

                Button(isSaving ? L10n.tr("login.button.saving") : L10n.tr("login.button.continue")) {
                    continueWithSelectedRole()
                }
                .buttonStyle(LumaPrimaryButtonStyle())
                .disabled(canContinue == false)
                .accessibilityLabel(L10n.tr("login.a11y.continue.label"))
                .accessibilityHint(
                    canContinue
                    ? L10n.tr("login.a11y.continue.hint.confirm")
                    : L10n.tr("login.a11y.continue.hint.select_first")
                )
                .accessibilitySortPriority(20)

                if isSwitchMode {
                    Button(L10n.tr("login.button.cancel")) {
                        sessionStore.cancelRoleSwitch()
                        AccessibilityAnnouncer.announce(L10n.tr("announcement.role_switch_canceled"))
                    }
                    .buttonStyle(LumaSecondaryButtonStyle())
                    .accessibilityLabel(L10n.tr("login.a11y.cancel.label"))
                    .accessibilityHint(L10n.tr("login.a11y.cancel.hint"))
                    .accessibilitySortPriority(10)
                }

                if let localError {
                    Text(localError)
                        .foregroundStyle(.red)
                        .accessibilityLabel(localError)
                        .accessibilitySortPriority(5)
                }
            }
            .padding(24)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("login.nav.title"))
        .inlineNavigationTitle()
        .onAppear {
            if isSwitchMode {
                selectedRole = sessionStore.currentRole
            }
        }
    }

    private func roleCard(_ role: AppRole, order index: Int) -> some View {
        let isSelected = selectedRole == role
        let stateText = isSelected
            ? L10n.tr("login.card.state.selected")
            : L10n.tr("login.card.state.not_selected")

        return Button {
            localError = nil
            selectedRole = role
            AccessibilityAnnouncer.announce(L10n.format("announcement.role_selected", role.title))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(role.title)
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)
                    Spacer()
                    Text(stateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? LumaPalette.accent : LumaPalette.secondaryText)
                }

                Text(role.summary)
                    .font(.subheadline)
                    .foregroundStyle(LumaPalette.secondaryText)

                Text(role.permissionHint)
                    .font(.footnote)
                    .foregroundStyle(LumaPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumaCardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? LumaPalette.accent : LumaPalette.cardBorder.opacity(0.8), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.format(
                "login.a11y.role_card_full",
                role.title,
                isSelected ? L10n.tr("login.a11y.state.selected") : L10n.tr("login.a11y.state.not_selected")
            )
        )
        .accessibilityHint(L10n.tr("login.a11y.role_card.hint"))
        .accessibilitySortPriority(Double(90 - index))
    }

    private func continueWithSelectedRole() {
        guard let selectedRole else {
            AccessibilityAnnouncer.announce(L10n.tr("announcement.select_role_first"))
            return
        }

        localError = nil
        isSaving = true

        do {
            try sessionStore.selectRole(selectedRole)
            AccessibilityAnnouncer.announce(L10n.format("announcement.role_switched", selectedRole.title))
        } catch {
            localError = L10n.tr("login.error.role_switch_failed")
            AccessibilityAnnouncer.announce(L10n.tr("announcement.role_switch_failed"))
        }

        isSaving = false
    }
}
