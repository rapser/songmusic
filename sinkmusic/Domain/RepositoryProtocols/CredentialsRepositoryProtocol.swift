//
//  CredentialsRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Proveedor de almacenamiento cloud seleccionado
enum CloudStorageProvider: String, Codable, Sendable {
    case googleDrive = "googleDrive"
    case mega = "mega"
}

/// Protocolo de repositorio para gestión de credenciales
/// Abstrae KeychainService de la capa de dominio
protocol CredentialsRepositoryProtocol: Sendable {

    // MARK: - Google Drive

    /// Carga las credenciales de Google Drive
    @MainActor func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool)

    /// Guarda las credenciales de Google Drive
    @MainActor func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool

    /// Elimina las credenciales de Google Drive
    @MainActor func deleteGoogleDriveCredentials()

    /// Verifica si hay credenciales de Google Drive configuradas
    @MainActor func hasGoogleDriveCredentials() -> Bool

    // MARK: - Mega

    /// Carga la URL de la carpeta de Mega
    @MainActor func loadMegaFolderURL() -> String

    /// Guarda la URL de la carpeta de Mega
    @MainActor func saveMegaFolderURL(_ url: String) -> Bool

    /// Elimina las credenciales de Mega
    @MainActor func deleteMegaCredentials()

    /// Verifica si hay credenciales de Mega configuradas
    @MainActor func hasMegaCredentials() -> Bool

    // MARK: - Provider Selection

    /// Obtiene el proveedor de almacenamiento seleccionado
    @MainActor func getSelectedCloudProvider() -> CloudStorageProvider

    /// Establece el proveedor de almacenamiento seleccionado
    @MainActor func setSelectedCloudProvider(_ provider: CloudStorageProvider)
}
