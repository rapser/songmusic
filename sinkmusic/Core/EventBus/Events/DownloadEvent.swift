//
//  DownloadEvent.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Core Layer - Event Bus Events
//

import Foundation

/// Eventos de descarga de canciones
/// Emitidos por DownloadUseCases/DataSource, consumidos por DownloadViewModel
enum DownloadEvent: Sendable {
    /// Descarga iniciada
    case started(songID: UUID)

    /// Progreso de descarga actualizado (0.0 - 1.0)
    case progress(songID: UUID, progress: Double)

    /// Descarga completada exitosamente
    case completed(songID: UUID)

    /// Descarga falló
    case failed(songID: UUID, error: String)

    /// Descarga cancelada
    case cancelled(songID: UUID)

    // MARK: - Queue Events

    /// Descarga agregada a la cola de espera
    case queued(songID: UUID, position: Int)

    /// Límite de cuota excedido para un proveedor
    case quotaExceeded(provider: String, resetTime: Date)
}
