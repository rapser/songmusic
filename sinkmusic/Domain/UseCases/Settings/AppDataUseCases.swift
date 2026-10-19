//
//  AppDataUseCases.swift
//  sinkmusic
//
//  Domain Layer - UseCase
//

import Foundation

/// Cuánto ocupa la app y cómo vaciarla.
///
/// Salió de `SettingsUseCases`. Son las operaciones destructivas y la medición que las
/// justifica: van juntas porque el usuario las usa en la misma secuencia —ver el tamaño,
/// decidir, borrar— y porque comparten las tres dependencias.
@MainActor
final class AppDataUseCases: Sendable {

    /// Tamaño que se asume por canción descargada.
    ///
    /// Es una estimación, no una medida: contar bytes de verdad obligaría a recorrer el
    /// directorio de música en cada apertura de Ajustes. Lo que se muestra es un orden de
    /// magnitud para decidir si merece la pena borrar, y para eso basta.
    private static let estimatedFileSizeMB: Double = 5.0

    private let songRepository: SongRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol

    init(
        songRepository: SongRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol,
        playlistRepository: PlaylistRepositoryProtocol
    ) {
        self.songRepository = songRepository
        self.cloudStorageRepository = cloudStorageRepository
        self.playlistRepository = playlistRepository
    }

    // MARK: - Measuring

    func getStorageInfo() async throws -> StorageInfo {
        let songs = try await songRepository.getAll()
        let downloadedSongs = songs.filter { $0.isDownloaded }

        let estimatedSize = Double(downloadedSongs.count) * Self.estimatedFileSizeMB

        // El artwork sí se puede medir exacto: está en la base de datos.
        let artworkBytes = songs.map { $0.artworkData?.count ?? 0 }.reduce(0, +)
        let artworkSizeMB = Double(artworkBytes) / (1024 * 1024)

        return StorageInfo(
            totalSongs: songs.count,
            downloadedSongs: downloadedSongs.count,
            estimatedAudioSizeMB: estimatedSize,
            artworkSizeMB: artworkSizeMB,
            totalSizeMB: estimatedSize + artworkSizeMB
        )
    }

    // MARK: - Clearing

    /// Suelta el artwork de las canciones **no descargadas**: es lo único realmente
    /// recuperable sin perder nada, porque se vuelve a traer de la nube cuando haga falta.
    /// El de las descargadas se queda, para que la biblioteca offline siga completa.
    func clearCache() async throws {
        let songs = try await songRepository.getAll()

        for song in songs where !song.isDownloaded {
            try await songRepository.update(song.clearingLocalArtwork())
        }
    }

    /// Vacía la biblioteca: archivos del disco, referencias en playlists y filas.
    ///
    /// Las playlists **sobreviven** vacías: son del usuario, las canciones son reemplazables.
    /// Quitar las referencias antes de borrar las filas evita dejar playlists apuntando a
    /// canciones que ya no existen.
    func deleteAllSongs() async throws {
        let songs = try await songRepository.getAll()

        for song in songs where song.isDownloaded {
            try? cloudStorageRepository.deleteDownload(for: song.id)
        }

        for song in songs {
            try? await playlistRepository.removeSongFromAllPlaylists(songID: song.id)
        }

        for song in songs {
            try await songRepository.delete(song.id)
        }
    }
}
