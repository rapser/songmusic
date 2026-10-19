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
/// canción tiene una ventana de 7 días **deslizante**, que se reinicia en cada
/// reproducción. Mientras se siga escuchando, la canción se mantiene en el ranking; 7 días
/// después de la última vez su contador se descarta y sale (puede reingresar si se vuelve
/// a escuchar). Así el listado de Inicio refleja lo que se está oyendo ahora sin castigar
/// justo a las canciones en rotación.
///
/// El contador acumula mientras la ventana siga viva, así que una canción oída a diario
/// durante meses puede asentarse en el puesto 1. Contar solo las reproducciones *dentro*
/// de los últimos 7 días exigiría guardar una fila por escucha en vez de un contador.
protocol RankingWindowRepositoryProtocol: Sendable {

    /// Registra una reproducción: incrementa el contador si la ventana sigue viva o abre
    /// una nueva si no existía o ya caducó. En ambos casos reancla la ventana a este momento.
    func registerPlay(songID: UUID) async

    /// Contadores vigentes por canción (las ventanas caducadas se ignoran). Para construir el ranking.
    func activeCounts() async -> [UUID: Int]

    /// Descarta el contador de una canción (p. ej. al borrarla de la biblioteca).
    func remove(songID: UUID) async

    /// Vacía todo el ranking.
    func clear() async
}
