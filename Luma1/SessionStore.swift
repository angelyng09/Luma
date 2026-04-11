//
//  SessionStore.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import Foundation
import Combine

enum AppRole: String, CaseIterable, Equatable, Identifiable {
    case lowVisionUser
    case venueMaintenance
    case communityManagement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowVisionUser:
            return L10n.tr("role.low_vision.title")
        case .venueMaintenance:
            return L10n.tr("role.venue_maintenance.title")
        case .communityManagement:
            return L10n.tr("role.community_management.title")
        }
    }

    var summary: String {
        switch self {
        case .lowVisionUser:
            return L10n.tr("role.low_vision.summary")
        case .venueMaintenance:
            return L10n.tr("role.venue_maintenance.summary")
        case .communityManagement:
            return L10n.tr("role.community_management.summary")
        }
    }

    var permissionHint: String {
        switch self {
        case .lowVisionUser:
            return L10n.tr("role.low_vision.permission")
        case .venueMaintenance:
            return L10n.tr("role.venue_maintenance.permission")
        case .communityManagement:
            return L10n.tr("role.community_management.permission")
        }
    }

    var switchedAnnouncement: String {
        L10n.format("announcement.role_switched", title)
    }
}

enum AuthMode: Equatable {
    case guest
    case account(email: String)
    case apple
    case role(AppRole)
}

enum SessionStoreError: LocalizedError {
    case roleSwitchPersistFailed

    var errorDescription: String? {
        switch self {
        case .roleSwitchPersistFailed:
            return L10n.tr("login.error.role_switch_failed")
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var authMode: AuthMode?
    @Published private(set) var isRoleSwitching = false
    private let authService: AuthServiceProtocol
    private let sessionStorage: SessionStorageProtocol

    convenience init() {
        self.init(restorePreviousSession: true)
    }

    convenience init(restorePreviousSession: Bool) {
        self.init(
            authService: LocalAuthService(),
            sessionStorage: UserDefaultsSessionStorage(),
            restorePreviousSession: restorePreviousSession
        )
    }

    init(
        authService: AuthServiceProtocol,
        sessionStorage: SessionStorageProtocol,
        restorePreviousSession: Bool = true
    ) {
        self.authService = authService
        self.sessionStorage = sessionStorage
        if restorePreviousSession {
            self.authMode = sessionStorage.loadAuthMode()
        } else {
            self.authMode = nil
            sessionStorage.saveAuthMode(nil)
        }
    }

    var isAuthenticated: Bool {
        authMode != nil
    }

    var shouldShowAuthEntry: Bool {
        authMode == nil
    }

    var shouldShowRoleSelection: Bool {
        if isRoleSwitching {
            return true
        }
        guard let authMode else {
            return false
        }
        switch authMode {
        case .account, .apple, .guest:
            return true
        case .role:
            return false
        }
    }

    var shouldShowHome: Bool {
        guard isRoleSwitching == false else {
            return false
        }
        guard case .role = authMode else {
            return false
        }
        return true
    }

    var currentRole: AppRole? {
        guard case let .role(role) = authMode else {
            return nil
        }
        return role
    }

    func beginRoleSwitch() {
        guard currentRole != nil else {
            return
        }
        isRoleSwitching = true
    }

    func cancelRoleSwitch() {
        isRoleSwitching = false
    }

    func selectRole(_ role: AppRole) throws {
        let previousAuthMode = authMode
        let previousRoleSwitching = isRoleSwitching

        authService.saveRoleForCurrentAccount(role)
        authMode = .role(role)
        isRoleSwitching = false
        sessionStorage.saveAuthMode(authMode)

        guard sessionStorage.loadAuthMode() == authMode else {
            authMode = previousAuthMode
            isRoleSwitching = previousRoleSwitching
            throw SessionStoreError.roleSwitchPersistFailed
        }
    }

    func login(email: String, password: String) async throws {
        let session = try await authService.login(email: email, password: password)
        if case .account = session.mode {
            authMode = .role(resolvedRoleForReturningAccount())
        } else {
            authMode = session.mode
        }
        sessionStorage.saveAuthMode(authMode)
    }

    func login(identifier: String, password: String) async throws {
        let session = try await authService.login(identifier: identifier, password: password)
        if case .account = session.mode {
            authMode = .role(resolvedRoleForReturningAccount())
        } else {
            authMode = session.mode
        }
        sessionStorage.saveAuthMode(authMode)
    }

    func register(email: String, password: String) async throws {
        let session = try await authService.register(email: email, password: password)
        authMode = session.mode
        sessionStorage.saveAuthMode(session.mode)
    }

    func register(email: String, username: String, password: String) async throws {
        let session = try await authService.register(email: email, username: username, password: password)
        authMode = session.mode
        sessionStorage.saveAuthMode(session.mode)
    }

    func signInWithApple() async throws {
        let session = try await authService.signInWithApple()
        authMode = session.mode
        sessionStorage.saveAuthMode(session.mode)
    }

    func continueAsGuest() async throws {
        let session = try await authService.continueAsGuest()
        authMode = session.mode
        sessionStorage.saveAuthMode(session.mode)
    }

    func currentAccountProfile() -> AccountProfile? {
        authService.currentAccountProfile()
    }

    func updateCurrentUsername(_ username: String) async throws -> AccountProfile {
        try await authService.updateCurrentUsername(username)
    }

    func updateCurrentPassword(_ password: String) async throws {
        try await authService.updateCurrentPassword(password)
    }

    func deleteCurrentAccount() async throws {
        try await authService.deleteCurrentAccount()
        logout()
    }

    func logout() {
        authMode = nil
        isRoleSwitching = false
        sessionStorage.saveAuthMode(nil)
    }

    private func resolvedRoleForReturningAccount() -> AppRole {
        if let savedRole = authService.savedRoleForCurrentAccount() {
            return savedRole
        }

        // Legacy accounts may not have a role mapping yet; auto-assign a safe default
        // so Sign In behaves like a returning-user flow without prompting role selection.
        let fallbackRole: AppRole = .lowVisionUser
        authService.saveRoleForCurrentAccount(fallbackRole)
        return fallbackRole
    }
}
