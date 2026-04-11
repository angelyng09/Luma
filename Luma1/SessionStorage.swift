//
//  SessionStorage.swift
//  Luma
//
//  Created by Codex on 2/28/26.
//

import Foundation

protocol SessionStorageProtocol {
    func loadAuthMode() -> AuthMode?
    func saveAuthMode(_ mode: AuthMode?)
}

struct UserDefaultsSessionStorage: SessionStorageProtocol {
    private let typeKey = "luma.session.type"
    private let emailKey = "luma.session.email"
    private let lastRoleSwitchAtKey = "last_role_switch_at"

    func loadAuthMode() -> AuthMode? {
        guard let type = UserDefaults.standard.string(forKey: typeKey) else {
            return nil
        }
        switch type {
        case "guest":
            return .guest
        case "account":
            let email = UserDefaults.standard.string(forKey: emailKey) ?? ""
            return .account(email: email)
        case "apple":
            return .apple
        case "role.low_vision_user":
            return .role(.lowVisionUser)
        case "role.venue_maintenance":
            return .role(.venueMaintenance)
        case "role.community_management":
            return .role(.communityManagement)
        default:
            return nil
        }
    }

    func saveAuthMode(_ mode: AuthMode?) {
        switch mode {
        case .guest:
            UserDefaults.standard.set("guest", forKey: typeKey)
            UserDefaults.standard.removeObject(forKey: emailKey)
        case .account(let email):
            UserDefaults.standard.set("account", forKey: typeKey)
            UserDefaults.standard.set(email, forKey: emailKey)
        case .apple:
            UserDefaults.standard.set("apple", forKey: typeKey)
            UserDefaults.standard.removeObject(forKey: emailKey)
        case .role(let role):
            switch role {
            case .lowVisionUser:
                UserDefaults.standard.set("role.low_vision_user", forKey: typeKey)
            case .venueMaintenance:
                UserDefaults.standard.set("role.venue_maintenance", forKey: typeKey)
            case .communityManagement:
                UserDefaults.standard.set("role.community_management", forKey: typeKey)
            }
            UserDefaults.standard.removeObject(forKey: emailKey)
            UserDefaults.standard.set(Date().ISO8601Format(), forKey: lastRoleSwitchAtKey)
        case .none:
            UserDefaults.standard.removeObject(forKey: typeKey)
            UserDefaults.standard.removeObject(forKey: emailKey)
            UserDefaults.standard.removeObject(forKey: lastRoleSwitchAtKey)
        }
    }
}
