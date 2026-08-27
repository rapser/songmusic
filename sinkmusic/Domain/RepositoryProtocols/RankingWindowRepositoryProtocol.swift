//
//  RankingWindowRepositoryProtocol.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Persiste el "contador con vida útil" del ranking de Inicio ("Canciones que más escuchas").
///
/// Vive FUERA de SwiftData a propósito: el ranking es estado volátil de presentación y no
/// debe forzar migraciones del `@Model` de canciones. Cada canción tiene una ventana de
/// 7 días que arranca en su primera reproducción del ciclo; al caducar, su contador se
/// descarta y la canción sale del ranking (puede reingresar si se vuelve a escuchar).
/// Así el listado de Inicio se mantiene fresco y ninguna canción se queda fija en el puesto 1.
protocol RankingWindowRepositoryProtocol: Sendable {

    /// Registra una reproducción de la canción: abre su ventana si no existía o ya caducó,
    /// o incrementa el contador si la ventana sigue viva.
    func registerPlay(songID: UUID)

    /// Contadores vigentes por canción (las ventanas caducadas se descartan y se persiste
    /// la limpieza). Solo lectura para construir el ranking.
    func activeCounts() -> [UUID: Int]

    /// Descarta el contador de una canción (p. ej. al borrarla de la biblioteca).
    func remove(songID: UUID)

    /// Vacía todo el ranking.
    func clear()
}
