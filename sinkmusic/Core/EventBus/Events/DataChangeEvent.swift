//
//  DataChangeEvent.swift
//  sinkmusic
//
//  Created by Claude Code
//  Core Layer - Event Bus Events
//

import Foundation

/// Eventos de cambios en datos (SwiftData, descargas, credenciales)
/// Emitidos por Data Layer, consumidos por Presentation Layer
enum DataChangeEvent: Sendable, Equatable {
    /// Las canciones fueron actualizadas (nuevo fetch, metadata cambiada)
    case songsUpdated

    /// Las playlists fueron actualizadas
    case playlistsUpdated

    /// Una canción fue eliminada
    case songDeleted(UUID)

    /// Una canción fue descargada exitosamente
    case songDownloaded(UUID)

    /// Las credenciales de cloud storage cambiaron
    case credentialsChanged

    /// Error en operación de datos
    case error(String)
}
