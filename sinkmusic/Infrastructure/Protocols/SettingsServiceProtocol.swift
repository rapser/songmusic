//
//  SettingsServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import Foundation
import SwiftData

// MARK: - Settings Service Protocol (Dependency Injection)

/// Protocolo para gestión de configuraciones y almacenamiento
protocol SettingsServiceProtocol: Sendable {
    /// Calcula el espacio de almacenamiento usado
    @MainActor func calculateStorageUsed(for songs: [Song]) -> String

    /// Filtra canciones pendientes
    func filterPendingSongs(_ songs: [Song]) -> [Song]

    /// Filtra canciones descargadas
    func filterDownloadedSongs(_ songs: [Song]) -> [Song]

    /// Elimina todas las descargas
    @MainActor
    func deleteAllDownloads(
        songs: [Song],
        modelContext: ModelContext
    ) async throws
}

/// Protocolo para gestión de credenciales
protocol CredentialsServiceProtocol: Sendable {
    /// Carga las credenciales guardadas
    func loadCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool)

    /// Guarda las credenciales
    func saveCredentials(apiKey: String, folderId: String) -> Bool

    /// Elimina las credenciales
    func deleteCredentials()

    /// Verifica si hay credenciales guardadas
    var hasCredentials: Bool { get }
}
