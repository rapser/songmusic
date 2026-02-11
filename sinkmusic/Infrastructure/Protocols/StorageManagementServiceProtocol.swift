//
//  StorageManagementServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation
import SwiftData

/// Protocolo para el servicio de gestión de almacenamiento
/// Permite mockear StorageManagementService para testing
protocol StorageManagementServiceProtocol: Sendable {

    // MARK: - Storage Calculation

    /// Calcula el espacio usado por las canciones descargadas
    /// - Parameter songs: Lista de canciones a evaluar
    /// - Returns: String formateado con el tamaño (ej: "150 MB")
    func calculateStorageUsed(for songs: [Song]) -> String

    // MARK: - Filtering

    /// Filtra canciones pendientes de descarga
    /// - Parameter songs: Lista de canciones
    /// - Returns: Canciones que no están descargadas
    func filterPendingSongs(_ songs: [Song]) -> [Song]

    /// Filtra canciones descargadas
    /// - Parameter songs: Lista de canciones
    /// - Returns: Canciones que están descargadas
    func filterDownloadedSongs(_ songs: [Song]) -> [Song]

    // MARK: - Deletion

    /// Elimina todas las descargas y actualiza el estado en la base de datos
    /// - Parameters:
    ///   - songs: Lista de canciones
    ///   - modelContext: Contexto de SwiftData para actualizar el estado
    @MainActor
    func deleteAllDownloads(songs: [Song], modelContext: ModelContext) async throws
}
