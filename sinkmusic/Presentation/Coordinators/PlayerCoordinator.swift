//
//  PlayerCoordinator.swift
//  sinkmusic
//

import Foundation

/// Coordina el estado de la canción en reproducción entre LibraryViewModel, PlayerViewModel
/// y MetadataCacheViewModel. Extrae la lógica de orquestación de MainAppView.
@MainActor
@Observable
final class PlayerCoordinator {

    // MARK: - Observable State

    private(set) var currentSong: SongUI?

    // MARK: - Private

    @ObservationIgnored
    private var songsLookup: [UUID: SongUI] = [:]

    private let metadataViewModel: MetadataCacheViewModel

    // MARK: - Init

    init(metadataViewModel: MetadataCacheViewModel) {
        self.metadataViewModel = metadataViewModel
    }

    // MARK: - Coordination

    /// Actualiza el lookup de canciones y sincroniza `currentSong` si hay reproducción activa.
    func onLibrarySongsChanged(_ songs: [SongUI], currentlyPlayingID: UUID?) {
        songsLookup = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        if let id = currentlyPlayingID, let updated = songsLookup[id] {
            currentSong = updated
        }
    }

    /// Reacciona al cambio de `currentlyPlayingID`: carga artwork y actualiza `currentSong`.
    func onPlayingIDChanged(_ id: UUID?, libraryViewModel: LibraryViewModel) async {
        guard let id else {
            metadataViewModel.clearCache()
            currentSong = nil
            return
        }
        guard let song = songsLookup[id] else { return }
        currentSong = song
        metadataViewModel.cacheArtwork(from: nil, thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail)
        let fullArtwork = await libraryViewModel.getArtworkData(songID: id)
        metadataViewModel.cacheArtwork(from: fullArtwork, thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail)
    }
}
