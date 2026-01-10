//
//  CredentialsRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para gestión de credenciales
/// Abstrae KeychainService de la capa de dominio
protocol CredentialsRepositoryProtocol: Sendable {

    /// Carga las credenciales de Google Drive
    @MainActor func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool)

    /// Guarda las credenciales de Google Drive
    @MainActor func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool

    /// Elimina las credenciales de Google Drive
    @MainActor func deleteGoogleDriveCredentials()

    /// Verifica si hay credenciales de Google Drive configuradas
    @MainActor func hasGoogleDriveCredentials() -> Bool
}
