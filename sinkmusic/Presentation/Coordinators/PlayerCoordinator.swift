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

    /// ID de la última canción para la que ya se cargó su artwork completo.
    /// Evita repetir el fetch async cada vez que la lista de la biblioteca cambia
    /// (sync, color dominante, play count, etc.) mientras sigue sonando la misma canción.
    @ObservationIgnored
    private var artworkLoadedSongID: UUID?

    private let metadataViewModel: MetadataCacheViewModel

    // MARK: - Init

    init(metadataViewModel: MetadataCacheViewModel) {
        self.metadataViewModel = metadataViewModel
    }

    // MARK: - Coordination

    /// Actualiza el lookup de canciones y sincroniza `currentSong` si hay reproducción activa.
    ///
    /// Solo actualiza `currentSong`; NO carga artwork — eso requiere un fetch async y lo hace
    /// `onPlayingIDChanged`. Al arrancar la app con una canción restaurada (ver
    /// `PlayerViewModel.restoreLastPlaybackState`), `currentlyPlayingID` ya viene fijado antes
    /// de que `MainAppView` se monte, así que `.onChange(of: currentlyPlayingID)` nunca se
    /// dispara para ese valor inicial. Por eso `MainAppView` llama a `onPlayingIDChanged`
    /// explícitamente también desde aquí, no solo desde el `.onChange`.
    func onLibrarySongsChanged(_ songs: [SongUI], currentlyPlayingID: UUID?) {
        songsLookup = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        if let id = currentlyPlayingID, let updated = songsLookup[id] {
            currentSong = updated
        }
    }

    /// Reacciona al cambio de `currentlyPlayingID`: carga artwork y actualiza `currentSong`.
    /// Idempotente para una misma canción ya cacheada, así que es seguro llamarlo tanto desde
    /// el `.onChange` como desde el estado inicial o desde cada refresco de la biblioteca.
    func onPlayingIDChanged(_ id: UUID?, libraryViewModel: LibraryViewModel) async {
        guard let id else {
            metadataViewModel.clearCache()
            currentSong = nil
            artworkLoadedSongID = nil
            return
        }
        guard let song = songsLookup[id] else { return }
        currentSong = song

        guard artworkLoadedSongID != id else { return }

        metadataViewModel.cacheArtwork(from: nil, thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail)
        let fullArtwork = await libraryViewModel.getArtworkData(songID: id)
        metadataViewModel.cacheArtwork(from: fullArtwork, thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail)
        artworkLoadedSongID = id
    }
}
