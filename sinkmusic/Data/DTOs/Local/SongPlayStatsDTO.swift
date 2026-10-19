//
//  SongPlayStatsDTO.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer (persistencia SwiftData)
//

import Foundation
import SwiftData

/// Contador histórico de reproducciones y última escucha de una canción.
///
/// Vivía como dos campos de `SongDTO` (`playCount`, `lastPlayedAt`), y eso convertía **dar
/// al play** en una escritura sobre la fila de la canción. Las cuatro tiendas del read-side
/// vigilan `SongDTO`, así que cada reproducción invalidaba Inicio, Biblioteca, Playlists y
/// Búsqueda enteras —4 señales, medidas en `ReadStoreFanOutTests`— aunque solo Inicio
/// muestre algo derivado del contador.
///
/// Entidad **independiente** (como `RankingWindowEntryDTO` y `PlaylistItemDTO`): se
/// relaciona por `songID` y no con `@Relationship`, para que añadirla sea una migración
/// puramente aditiva sobre el esquema de `SongDTO`, que es frágil por sus
/// `@Attribute(.unique)`.
///
/// `SongPlayStatsLocalDataSource` es el único que la escribe. Los campos viejos de `SongDTO`
/// **no se borran** —quitarlos sí exigiría un `AppSchemaV2`— y quedan solo como semilla del
/// backfill perezoso.
@Model
final class SongPlayStatsDTO {
    @Attribute(.unique) var songID: UUID
    var playCount: Int
    var lastPlayedAt: Date?

    init(songID: UUID, playCount: Int = 0, lastPlayedAt: Date? = nil) {
        self.songID = songID
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

/// Las estadísticas de una canción, ya fuera de SwiftData. Es lo que el `SongMapper` necesita
/// para completar un `Song` sin conocer la entidad.
struct SongPlayStats: Equatable, Sendable {
    let playCount: Int
    let lastPlayedAt: Date?

    static let none = SongPlayStats(playCount: 0, lastPlayedAt: nil)
}
