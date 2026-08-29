//
//  RankingWindowRepositoryProtocol.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Contrato del "contador con vida útil" del ranking de Inicio ("Canciones que más escuchas").
///
/// El ranking es estado de presentación, independiente del `playCount` histórico: cada
/// canción tiene una ventana de 7 días que arranca en su primera reproducción del ciclo;
/// al caducar, su contador se descarta y la canción sale del ranking (puede reingresar si
/// se vuelve a escuchar). Así el listado de Inicio se mantiene fresco y ninguna canción se
/// queda fija en el puesto 1.
protocol RankingWindowRepositoryProtocol: Sendable {

    /// Registra una reproducción: abre la ventana si no existía o ya caducó, o incrementa
    /// el contador si sigue viva.
    func registerPlay(songID: UUID) async

    /// Contadores vigentes por canción (las ventanas caducadas se ignoran). Para construir el ranking.
    func activeCounts() async -> [UUID: Int]

    /// Descarta el contador de una canción (p. ej. al borrarla de la biblioteca).
    func remove(songID: UUID) async

    /// Vacía todo el ranking.
    func clear() async
}
