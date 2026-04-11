//
//  AuthService.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import Foundation

struct AuthSession {
    let mode: AuthMode
}

struct AccountProfile: Equatable {
    let email: String
    let username: String
}

private struct LocalAccount: Codable {
    let email: String
    let username: String
    let password: String
}

protocol AuthServiceProtocol {
    func login(email: String, password: String) async throws -> AuthSession
    func register(email: String, password: String) async throws -> AuthSession
    func login(identifier: String, password: String) async throws -> AuthSession
    func register(email: String, username: String, password: String) async throws -> AuthSession
    func signInWithApple() async throws -> AuthSession
    func continueAsGuest() async throws -> AuthSession
    func currentAccountProfile() -> AccountProfile?
    func updateCurrentUsername(_ username: String) async throws -> AccountProfile
    func updateCurrentPassword(_ password: String) async throws
    func deleteCurrentAccount() async throws
    func saveRoleForCurrentAccount(_ role: AppRole)
    func savedRoleForCurrentAccount() -> AppRole?
}

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidUsername
    case weakPassword
    case invalidCredentials
    case accountAlreadyExists
    case accountNotFound
    case usernameTaken
    case noActiveAccount

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return L10n.tr("auth.error.invalid_email")
        case .invalidUsername:
            return L10n.tr("auth.error.invalid_username")
        case .weakPassword:
            return L10n.tr("auth.error.weak_password")
        case .invalidCredentials:
            return L10n.tr("auth.error.invalid_credentials")
        case .accountAlreadyExists:
            return L10n.tr("auth.error.account_exists")
        case .accountNotFound:
            return L10n.tr("auth.error.account_not_found")
        case .usernameTaken:
            return L10n.tr("auth.error.username_taken")
        case .noActiveAccount:
            return L10n.tr("auth.error.no_active_account")
        }
    }
}

struct LocalAuthService: AuthServiceProtocol {
    private let storageKey = "luma.local.accounts"
    private let activeAccountEmailKey = "luma.active.account.email"
    private let accountRoleMapKey = "luma.account.role.map"

    func login(email: String, password: String) async throws -> AuthSession {
        try await login(identifier: email, password: password)
    }

    func register(email: String, password: String) async throws -> AuthSession {
        let inferredUsername = String(email.split(separator: "@").first ?? "")
        return try await register(email: email, username: inferredUsername, password: password)
    }

    func login(identifier: String, password: String) async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(250))
        let normalizedIdentifier = normalizeIdentifier(identifier)
        let accounts = loadAccounts()
        guard let account = accounts.first(where: {
            $0.email == normalizedIdentifier || $0.username == normalizedIdentifier
        }) else {
            throw AuthError.accountNotFound
        }
        guard account.password == password else {
            throw AuthError.invalidCredentials
        }
        setActiveAccountEmail(account.email)
        return AuthSession(mode: .account(email: account.email))
    }

    func register(email: String, username: String, password: String) async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(250))
        let normalizedEmail = try normalizeEmail(email)
        let normalizedUsername = try normalizeUsername(username)
        var accounts = loadAccounts()
        if accounts.contains(where: { $0.email == normalizedEmail }) {
            throw AuthError.accountAlreadyExists
        }
        if accounts.contains(where: { $0.username == normalizedUsername }) {
            throw AuthError.usernameTaken
        }
        accounts.append(LocalAccount(email: normalizedEmail, username: normalizedUsername, password: password))
        saveAccounts(accounts)
        setActiveAccountEmail(normalizedEmail)
        return AuthSession(mode: .account(email: normalizedEmail))
    }

    func signInWithApple() async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(350))
        clearActiveAccountEmail()
        return AuthSession(mode: .apple)
    }

    func continueAsGuest() async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(150))
        clearActiveAccountEmail()
        return AuthSession(mode: .guest)
    }

    func currentAccountProfile() -> AccountProfile? {
        guard let activeEmail = loadActiveAccountEmail() else {
            return nil
        }
        guard let account = loadAccounts().first(where: { $0.email == activeEmail }) else {
            return nil
        }
        return AccountProfile(email: account.email, username: account.username)
    }

    func updateCurrentUsername(_ username: String) async throws -> AccountProfile {
        try await Task.sleep(for: .milliseconds(180))
        let normalizedUsername = try normalizeUsername(username)
        var accounts = loadAccounts()

        guard
            let activeEmail = loadActiveAccountEmail(),
            let currentIndex = accounts.firstIndex(where: { $0.email == activeEmail })
        else {
            throw AuthError.noActiveAccount
        }

        if accounts.contains(where: { $0.username == normalizedUsername && $0.email != activeEmail }) {
            throw AuthError.usernameTaken
        }

        let current = accounts[currentIndex]
        let updated = LocalAccount(email: current.email, username: normalizedUsername, password: current.password)
        accounts[currentIndex] = updated
        saveAccounts(accounts)
        return AccountProfile(email: updated.email, username: updated.username)
    }

    func updateCurrentPassword(_ password: String) async throws {
        try await Task.sleep(for: .milliseconds(180))
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        var accounts = loadAccounts()
        guard
            let activeEmail = loadActiveAccountEmail(),
            let currentIndex = accounts.firstIndex(where: { $0.email == activeEmail })
        else {
            throw AuthError.noActiveAccount
        }

        let current = accounts[currentIndex]
        let updated = LocalAccount(email: current.email, username: current.username, password: password)
        accounts[currentIndex] = updated
        saveAccounts(accounts)
    }

    func deleteCurrentAccount() async throws {
        try await Task.sleep(for: .milliseconds(220))
        var accounts = loadAccounts()

        guard
            let activeEmail = loadActiveAccountEmail(),
            let currentIndex = accounts.firstIndex(where: { $0.email == activeEmail })
        else {
            throw AuthError.noActiveAccount
        }

        accounts.remove(at: currentIndex)
        saveAccounts(accounts)
        removeSavedRole(for: activeEmail)
        clearActiveAccountEmail()
    }

    func saveRoleForCurrentAccount(_ role: AppRole) {
        guard let activeEmail = loadActiveAccountEmail() else {
            return
        }
        var roleMap = loadRoleMap()
        roleMap[activeEmail] = role.rawValue
        saveRoleMap(roleMap)
    }

    func savedRoleForCurrentAccount() -> AppRole? {
        guard let activeEmail = loadActiveAccountEmail() else {
            return nil
        }
        let roleMap = loadRoleMap()
        guard let rawValue = roleMap[activeEmail] else {
            return nil
        }
        return AppRole(rawValue: rawValue)
    }

    private func normalizeEmail(_ email: String) throws -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), normalized.contains(".") else {
            throw AuthError.invalidEmail
        }
        return normalized
    }

    private func normalizeIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeUsername(_ username: String) throws -> String {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count >= 2 else {
            throw AuthError.invalidUsername
        }
        return normalized
    }

    private func loadAccounts() -> [LocalAccount] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([LocalAccount].self, from: data)) ?? []
    }

    private func saveAccounts(_ accounts: [LocalAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadActiveAccountEmail() -> String? {
        let value = UserDefaults.standard.string(forKey: activeAccountEmailKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let value, value.isEmpty == false {
            return value
        }
        return nil
    }

    private func setActiveAccountEmail(_ email: String) {
        UserDefaults.standard.set(email.lowercased(), forKey: activeAccountEmailKey)
    }

    private func clearActiveAccountEmail() {
        UserDefaults.standard.removeObject(forKey: activeAccountEmailKey)
    }

    private func loadRoleMap() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: accountRoleMapKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveRoleMap(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else {
            return
        }
        UserDefaults.standard.set(data, forKey: accountRoleMapKey)
    }

    private func removeSavedRole(for email: String) {
        var roleMap = loadRoleMap()
        roleMap.removeValue(forKey: email)
        saveRoleMap(roleMap)
    }
}
