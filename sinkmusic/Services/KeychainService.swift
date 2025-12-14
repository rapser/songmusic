//
//  KeychainService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import Security

/// Servicio para almacenar y recuperar credenciales de forma segura usando Keychain
final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    enum KeychainKey: String {
        case googleDriveAPIKey = "com.sinkmusic.googleDriveAPIKey"
        case googleDriveFolderId = "com.sinkmusic.googleDriveFolderId"
    }

    // MARK: - Save

    /// Guarda un valor en el Keychain
    func save(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        // Primero intentar eliminar el valor existente
        delete(for: key)

        // Crear query para guardar
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Retrieve

    /// Recupera un valor del Keychain
    func retrieve(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Delete

    /// Elimina un valor del Keychain
    @discardableResult
    func delete(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Helpers para Google Drive

    var googleDriveAPIKey: String? {
        get { retrieve(for: .googleDriveAPIKey) }
        set {
            if let value = newValue {
                _ = save(value, for: .googleDriveAPIKey)
            } else {
                _ = delete(for: .googleDriveAPIKey)
            }
        }
    }

    var googleDriveFolderId: String? {
        get { retrieve(for: .googleDriveFolderId) }
        set {
            if let value = newValue {
                _ = save(value, for: .googleDriveFolderId)
            } else {
                _ = delete(for: .googleDriveFolderId)
            }
        }
    }

    /// Verifica si las credenciales de Google Drive están configuradas
    var hasGoogleDriveCredentials: Bool {
        return googleDriveAPIKey != nil && googleDriveFolderId != nil
    }
}
