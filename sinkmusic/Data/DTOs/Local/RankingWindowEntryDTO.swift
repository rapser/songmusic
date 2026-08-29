//
//  RankingWindowEntryDTO.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer (persistencia SwiftData)
//

import Foundation
import SwiftData

/// Contador con ventana de vida para el ranking de Inicio ("Canciones que más escuchas").
///
/// Entidad SwiftData **independiente** de `SongDTO`: el ranking es estado de presentación
/// (se resetea a los 7 días) y no debe mezclarse con el `playCount` histórico ni forzar
/// migraciones del modelo de canciones. Una fila por canción con reproducciones en el ciclo
/// actual; `windowStartedAt` marca el inicio de su ventana de 7 días.
@Model
final class RankingWindowEntryDTO {
    @Attribute(.unique) var songID: UUID
    var count: Int
    var windowStartedAt: Date

    init(songID: UUID, count: Int, windowStartedAt: Date) {
        self.songID = songID
        self.count = count
        self.windowStartedAt = windowStartedAt
    }
}
