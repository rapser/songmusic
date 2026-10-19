//
//  HomePlaylistLayoutUseCases.swift
//  sinkmusic
//
//  Domain Layer - UseCase
//

import Foundation

/// Qué playlists se ven en Inicio y en qué orden.
///
/// Salió de `PlaylistUseCases`, que son el CRUD de playlists. Esto no es CRUD: es una
/// preferencia de presentación del usuario —qué cuatro celdas de la rejilla de Inicio ocupa
/// qué— guardada aparte y con sus propias reglas de tope y de reconciliación cuando aparece
/// o desaparece una playlist. Dos motivos de cambio distintos, y `PlaylistUseCases` cargaba
/// con el repositorio de la curaduría solo para estos dos métodos.
@MainActor
final class HomePlaylistLayoutUseCases: Sendable {

    private let playlistRepository: PlaylistRepositoryProtocol
    private let homePlaylistLayoutRepository: HomePlaylistLayoutRepositoryProtocol

    init(
        playlistRepository: PlaylistRepositoryProtocol,
        homePlaylistLayoutRepository: HomePlaylistLayoutRepositoryProtocol
    ) {
        self.playlistRepository = playlistRepository
        self.homePlaylistLayoutRepository = homePlaylistLayoutRepository
    }

    /// Tope de playlists en Inicio: coincide con las 2 columnas × 2 filas de `PlaylistGridView`.
    /// La posición dentro de "Inicio" determina la celda: 1º arriba-izquierda, 2º arriba-derecha,
    /// 3º abajo-izquierda, 4º abajo-derecha.
    static let maxHomePlaylistsCount = 4

    /// Playlists a mostrar en Inicio (curadas por el usuario, máximo `maxHomePlaylistsCount`)
    /// y el resto ("Otros").
    ///
    /// Sin preferencia guardada, cae al comportamiento histórico: las 4 más recientes
    /// (ya vienen ordenadas por `updatedAt` desde el repositorio). Las playlists nuevas
    /// que no estaban en el orden guardado se agregan al final de "Otros" — curar Inicio
    /// es una decisión explícita del usuario, no algo que una playlist nueva deba invadir.
    func getHomePlaylistLayout() async throws -> (shown: [Playlist], others: [Playlist]) {
        let all = try await playlistRepository.getAll()

        guard let saved = homePlaylistLayoutRepository.load(), !saved.order.isEmpty else {
            let shown = Array(all.prefix(Self.maxHomePlaylistsCount))
            let shownIDs = Set(shown.map(\.id))
            return (shown, all.filter { !shownIDs.contains($0.id) })
        }

        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        var ordered = saved.order.compactMap { byID[$0] }

        let orderedIDs = Set(ordered.map(\.id))
        let missing = all.filter { !orderedIDs.contains($0.id) }
        ordered.append(contentsOf: missing)

        let maxAllowed = min(ordered.count, Self.maxHomePlaylistsCount)
        let homeCount = min(max(saved.homeCount, 0), maxAllowed)
        return (Array(ordered.prefix(homeCount)), Array(ordered.suffix(from: homeCount)))
    }

    /// Guarda la curaduría de Inicio: qué playlists se muestran y en qué orden (`shownIDs`),
    /// y en qué orden quedan las que no se muestran (`otherIDs`).
    ///
    /// `shownIDs` nunca debería traer más de `maxHomePlaylistsCount`, pero por si acaso se
    /// recorta aquí también: el exceso se corre al frente de "Otros" en vez de perderse.
    func updateHomePlaylistLayout(shownIDs: [UUID], otherIDs: [UUID]) {
        let cappedShown = Array(shownIDs.prefix(Self.maxHomePlaylistsCount))
        let overflow = Array(shownIDs.dropFirst(Self.maxHomePlaylistsCount))
        homePlaylistLayoutRepository.save(order: cappedShown + overflow + otherIDs, homeCount: cappedShown.count)
    }
}
