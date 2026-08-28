//
//  PlaylistUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para gestión de playlists
/// Maneja creación, edición y organización de playlists
@MainActor
final class PlaylistUseCases {

    // MARK: - Dependencies

    private let playlistRepository: PlaylistRepositoryProtocol
    private let songRepository: SongRepositoryProtocol
    private let homePlaylistLayoutRepository: HomePlaylistLayoutRepositoryProtocol

    // MARK: - Initialization

    init(
        playlistRepository: PlaylistRepositoryProtocol,
        songRepository: SongRepositoryProtocol,
        homePlaylistLayoutRepository: HomePlaylistLayoutRepositoryProtocol
    ) {
        self.playlistRepository = playlistRepository
        self.songRepository = songRepository
        self.homePlaylistLayoutRepository = homePlaylistLayoutRepository
    }

    // MARK: - Playlist Access

    /// Obtiene todas las playlists
    func getAllPlaylists() async throws -> [Playlist] {
        return try await playlistRepository.getAll()
    }

    /// Obtiene las playlists más escuchadas (ordenadas por suma de playCount de sus canciones).
    /// Útil para la sección horizontal "Playlists más escuchadas" en Inicio.
    ///
    /// Excepción aceptada: ordenar por una suma calculada sobre una relación (`songs.playCount`)
    /// no es expresable en `SortDescriptor`/`#Predicate` de SwiftData — no hay agregación sobre
    /// relaciones a nivel de FetchDescriptor. Se deja en memoria; si el volumen lo justifica en el
    /// futuro, se podría denormalizar un campo cacheado de "total plays" en `PlaylistDTO`.
    func getMostPlayedPlaylists(limit: Int = 10) async throws -> [Playlist] {
        let all = try await playlistRepository.getAll()
        return Array(
            all.sorted { p1, p2 in
                let total1 = p1.songs.reduce(0) { $0 + $1.playCount }
                let total2 = p2.songs.reduce(0) { $0 + $1.playCount }
                return total1 > total2
            }
            .prefix(limit)
        )
    }

    /// Obtiene una playlist por ID
    func getPlaylistByID(_ id: UUID) async throws -> Playlist? {
        return try await playlistRepository.getByID(id)
    }

    // MARK: - Playlist Management

    /// Crea una nueva playlist
    func createPlaylist(name: String, description: String?, coverImageData: Data?, placeholderColorIndex: Int? = nil) async throws -> Playlist {
        let newPlaylist = Playlist(
            id: UUID(),
            name: name,
            description: description ?? "",
            createdAt: Date(),
            updatedAt: Date(),
            coverImageData: coverImageData,
            placeholderColorIndex: placeholderColorIndex,
            songs: []
        )

        return try await playlistRepository.create(newPlaylist)
    }

    /// Actualiza una playlist existente
    func updatePlaylist(_ playlist: Playlist) async throws {
        try await playlistRepository.update(playlist)
    }

    /// Elimina una playlist
    func deletePlaylist(_ id: UUID) async throws {
        try await playlistRepository.delete(id)
    }

    /// Renombra una playlist
    func renamePlaylist(_ id: UUID, newName: String) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        playlist = Playlist(
            id: playlist.id,
            name: newName,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: Date(),
            coverImageData: playlist.coverImageData,
            placeholderColorIndex: playlist.placeholderColorIndex,
            songs: playlist.songs
        )

        try await playlistRepository.update(playlist)
    }

    // MARK: - Song Management in Playlist

    /// Agrega una canción a una playlist
    func addSongToPlaylist(songID: UUID, playlistID: UUID) async throws {
        // Verificar que la canción existe
        guard try await songRepository.getByID(songID) != nil else {
            throw PlaylistError.songNotFound
        }

        try await playlistRepository.addSong(songID: songID, toPlaylist: playlistID)
    }

    /// Remueve una canción de una playlist
    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) async throws {
        try await playlistRepository.removeSong(songID: songID, fromPlaylist: playlistID)
    }

    /// Agrega múltiples canciones a una playlist
    func addSongsToPlaylist(songIDs: [UUID], playlistID: UUID) async throws {
        for songID in songIDs {
            try await addSongToPlaylist(songID: songID, playlistID: playlistID)
        }
    }

    /// Obtiene las canciones de una playlist
    func getSongsInPlaylist(_ playlistID: UUID) async throws -> [Song] {
        guard let playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        return playlist.songs
    }

    // MARK: - Playlist Organization

    /// Reordena canciones en una playlist
    func reorderSongs(in playlistID: UUID, fromOffsets: IndexSet, toOffset: Int) async throws {
        guard let playlist = try await playlistRepository.getByID(playlistID) else {
            throw PlaylistError.notFound
        }

        // Reordenar el array de IDs y persistir con updateSongsOrder,
        // que escribe directamente playlist.songs en SwiftData.
        // update() no toca el array de canciones — por eso el orden se perdía.
        var songIDs = playlist.songs.map { $0.id }
        songIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)

        try await playlistRepository.updateSongsOrder(playlistID: playlistID, songIDs: songIDs)
    }

    /// Limpia una playlist (remueve todas las canciones)
    func clearPlaylist(_ id: UUID) async throws {
        guard var playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        playlist = Playlist(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: Date(),
            coverImageData: playlist.coverImageData,
            placeholderColorIndex: playlist.placeholderColorIndex,
            songs: []
        )

        try await playlistRepository.update(playlist)
    }

    // MARK: - Home Layout

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

    // MARK: - Statistics

    /// Obtiene estadísticas de una playlist
    func getPlaylistStats(_ id: UUID) async throws -> PlaylistStats {
        guard let playlist = try await playlistRepository.getByID(id) else {
            throw PlaylistError.notFound
        }

        let songs = try await getSongsInPlaylist(id)
        let totalDuration = songs.compactMap { $0.duration }.reduce(0, +)
        let totalPlays = songs.map { $0.playCount }.reduce(0, +)
        let downloadedSongs = songs.filter { $0.isDownloaded }.count

        return PlaylistStats(
            songCount: playlist.songs.count,
            totalDuration: totalDuration,
            totalPlays: totalPlays,
            downloadedSongs: downloadedSongs
        )
    }
}

// MARK: - Playlist Stats

struct PlaylistStats: Sendable {
    let songCount: Int
    let totalDuration: TimeInterval
    let totalPlays: Int
    let downloadedSongs: Int

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Sendable Conformance

extension PlaylistUseCases: Sendable {}
