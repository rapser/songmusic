//
//  HomePlaylistLayoutViewModel.swift
//  sinkmusic
//
//  Curaduría de qué playlists se muestran en Inicio y en qué orden (pantalla "Editar inicio").
//  Extraído de `PlaylistViewModel` (que mezclaba CRUD de playlists + detalle + esta curaduría).
//

import Foundation
import os

@MainActor
@Observable
final class HomePlaylistLayoutViewModel {

    /// Playlists visibles en Inicio (curadas por el usuario, máx. `PlaylistUseCases.maxHomePlaylistsCount`).
    var homeShownPlaylists: [PlaylistUI] = []
    /// El resto ("Otros").
    var homeOtherPlaylists: [PlaylistUI] = []

    /// `true` cuando Inicio ya tiene el máximo de playlists permitido.
    var isHomePlaylistsFull: Bool {
        homeShownPlaylists.count >= PlaylistUseCases.maxHomePlaylistsCount
    }

    private let playlistUseCases: PlaylistUseCases
    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "HomeLayout")

    init(playlistUseCases: PlaylistUseCases) {
        self.playlistUseCases = playlistUseCases
    }

    /// Carga la curaduría actual: playlists en Inicio (y su orden) y el resto ("Otros").
    func loadHomePlaylistLayout() async {
        do {
            let layout = try await playlistUseCases.getHomePlaylistLayout()
            homeShownPlaylists = layout.shown.map(PlaylistMapper.toUI)
            homeOtherPlaylists = layout.others.map(PlaylistMapper.toUI)
        } catch {
            logger.error("Error al cargar la curaduría de Inicio: \(error)")
        }
    }

    func moveHomePlaylistWithinShown(fromOffsets: IndexSet, toOffset: Int) {
        homeShownPlaylists.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persistHomePlaylistLayout()
    }

    func moveHomePlaylistWithinOthers(fromOffsets: IndexSet, toOffset: Int) {
        homeOtherPlaylists.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persistHomePlaylistLayout()
    }

    func movePlaylistToHome(_ id: UUID) {
        guard !homeShownPlaylists.contains(where: { $0.id == id }),
              let index = homeOtherPlaylists.firstIndex(where: { $0.id == id }),
              homeShownPlaylists.count < PlaylistUseCases.maxHomePlaylistsCount else {
            return
        }
        homeShownPlaylists.append(homeOtherPlaylists.remove(at: index))
        persistHomePlaylistLayout()
    }

    func movePlaylistToOthers(_ id: UUID) {
        guard !homeOtherPlaylists.contains(where: { $0.id == id }),
              let index = homeShownPlaylists.firstIndex(where: { $0.id == id }) else {
            return
        }
        homeOtherPlaylists.append(homeShownPlaylists.remove(at: index))
        persistHomePlaylistLayout()
    }

    private func persistHomePlaylistLayout() {
        playlistUseCases.updateHomePlaylistLayout(
            shownIDs: homeShownPlaylists.map(\.id),
            otherIDs: homeOtherPlaylists.map(\.id)
        )
    }
}
