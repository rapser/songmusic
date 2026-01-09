//
//  KeychainServiceProtocol.swift
//  sinkmusic
//
//  Created by Claude Code - Clean Architecture
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de Keychain
/// Permite mockear KeychainService para testing
protocol KeychainServiceProtocol: Sendable {

    // MARK: - Save

    /// Guarda un valor en el Keychain
    func save(_ value: String, for key: KeychainService.KeychainKey) -> Bool

    // MARK: - Retrieve

    /// Recupera un valor del Keychain
    func retrieve(for key: KeychainService.KeychainKey) -> String?

    // MARK: - Delete

    /// Elimina un valor del Keychain
    @discardableResult
    func delete(for key: KeychainService.KeychainKey) -> Bool

    // MARK: - Google Drive Helpers

    /// API Key de Google Drive
    var googleDriveAPIKey: String? { get set }

    /// Folder ID de Google Drive
    var googleDriveFolderId: String? { get set }

    /// Verifica si las credenciales de Google Drive están configuradas
    var hasGoogleDriveCredentials: Bool { get }
}
