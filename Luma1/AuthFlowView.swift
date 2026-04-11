//
//  AuthFlowView.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import SwiftUI

private enum AuthRoute: Hashable {
    case signIn
    case createAccount
}

struct AuthFlowView: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sessionStore.shouldShowAuthEntry {
                    AuthEntryChoiceView(
                        onSignIn: { path.append(.signIn) },
                        onCreateAccount: { path.append(.createAccount) }
                    )
                } else {
                    RoleSelectionView(sessionStore: sessionStore)
                }
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signIn:
                    SignInPageView(
                        sessionStore: sessionStore,
                        onCreateAccount: { path.append(.createAccount) }
                    )
                case .createAccount:
                    CreateAccountPageView(sessionStore: sessionStore)
                }
            }
        }
        .onChange(of: sessionStore.shouldShowAuthEntry) { _, shouldShowAuthEntry in
            if shouldShowAuthEntry == false {
                path.removeAll()
            }
        }
    }
}

struct HomeView: View {
    @ObservedObject var sessionStore: SessionStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    private var roleTitle: String {
        if case let .role(role) = sessionStore.authMode {
            return role.title
        }
        return L10n.tr("home.role.unknown")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.tr("home.title"))
                    .font(.title.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                Text(L10n.format("home.current_role", roleTitle))
                    .foregroundStyle(.secondary)

                Button(L10n.tr("home.button.switch_role")) {
                    sessionStore.beginRoleSwitch()
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.role_switch_start"))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.tr("home.button.switch_role"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .navigationTitle(L10n.tr("home.nav.title"))
            .inlineNavigationTitle()
        }
        .onAppear {
            isTitleFocused = true
            AccessibilityAnnouncer.announce(L10n.tr("announcement.home_page"))
        }
    }
}

struct AuthFlowView_Previews: PreviewProvider {
    static var previews: some View {
        AuthFlowView(sessionStore: SessionStore())
            .environmentObject(LanguageStore())
    }
}
