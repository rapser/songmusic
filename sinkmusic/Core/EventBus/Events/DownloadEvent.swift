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
    case failed(songID: UUID, failure: DownloadFailure)

    /// Descarga cancelada
    case cancelled(songID: UUID)

    // MARK: - Queue Events

    /// Descarga agregada a la cola de espera
    case queued(songID: UUID, position: Int)

    // Nota: hubo un `.quotaExceeded`. Lo emitía `DownloadViewModel` y lo consumía él mismo,
    // y su handler repetía lo que el código imperativo ya había hecho dos líneas antes. El
    // estado de cuota vive en `DownloadQueueManager`, que es compartido. Si algún día lo
    // emite la capa de datos, vuelve.
}
