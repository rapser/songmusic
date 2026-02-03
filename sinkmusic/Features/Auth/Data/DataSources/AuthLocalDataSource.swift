//
//  AuthLocalDataSource.swift
//  sinkmusic
//
//  Features/Auth - Data Layer DataSource
//  Clean Architecture: Acceso a datos locales de autenticación
//

import Foundation

/// Protocolo para el DataSource local de autenticación
protocol AuthLocalDataSourceProtocol: Sendable {
    func saveUser(id: String, email: String?, fullName: String?)
    func getStoredUserID() -> String?
    func getStoredEmail() -> String?
    func getStoredFullName() -> String?
    func clearUser()
    func setDidSignOut(_ value: Bool)
    func didUserSignOut() -> Bool
}

/// DataSource para datos de autenticación almacenados localmente
/// Usa UserDefaults para persistencia simple
final class AuthLocalDataSource: AuthLocalDataSourceProtocol, @unchecked Sendable {

    // MARK: - Keys

    private enum Keys {
        static let userID = "appleUserID"
        static let email = "appleUserEmail"
        static let fullName = "appleUserFullName"
        static let didSignOut = "didUserSignOut"
    }

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Save

    func saveUser(id: String, email: String?, fullName: String?) {
        userDefaults.set(id, forKey: Keys.userID)

        if let email = email {
            userDefaults.set(email, forKey: Keys.email)
        }

        if let fullName = fullName {
            userDefaults.set(fullName, forKey: Keys.fullName)
        }

        userDefaults.set(false, forKey: Keys.didSignOut)
        userDefaults.synchronize()
    }

    // MARK: - Read

    func getStoredUserID() -> String? {
        userDefaults.string(forKey: Keys.userID)
    }

    func getStoredEmail() -> String? {
        userDefaults.string(forKey: Keys.email)
    }

    func getStoredFullName() -> String? {
        userDefaults.string(forKey: Keys.fullName)
    }

    func didUserSignOut() -> Bool {
        userDefaults.bool(forKey: Keys.didSignOut)
    }

    // MARK: - Clear

    func clearUser() {
        userDefaults.removeObject(forKey: Keys.userID)
        userDefaults.set(true, forKey: Keys.didSignOut)
        userDefaults.synchronize()
    }

    func setDidSignOut(_ value: Bool) {
        userDefaults.set(value, forKey: Keys.didSignOut)
        userDefaults.synchronize()
    }
}
