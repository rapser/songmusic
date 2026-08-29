//
//  PlaylistItemDTO.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer (persistencia SwiftData)
//

import Foundation
import SwiftData

/// Orden de una canción dentro de una playlist.
///
/// Sustituye a `PlaylistDTO.songOrder` (CSV de UUIDs "uuid1,uuid2,..." — hallazgo N de la
/// auditoría: había que parsear y re-serializar el string en cada add/remove/reorder y
/// mantenerlo en sync con la relación `@Relationship`, imposible de consultar y fácil de
/// desincronizar).
///
/// Entidad **independiente** (como `RankingWindowEntryDTO`): se relaciona con la playlist por
/// `playlistID`, no con `@Relationship`, para que añadirla sea una migración puramente
/// aditiva sobre el esquema de `PlaylistDTO`/`SongDTO`.
///
/// `PlaylistLocalDataSource` es el único que la escribe y garantiza el invariante:
/// exactamente una fila por (playlistID, songID) presente en `playlist.songs`, con
/// `position` contiguo desde 0. `songOrder` queda solo como fuente del backfill inicial.
@Model
final class PlaylistItemDTO {
    var playlistID: UUID
    var songID: UUID
    var position: Int

    init(playlistID: UUID, songID: UUID, position: Int) {
        self.playlistID = playlistID
        self.songID = songID
        self.position = position
    }
}
