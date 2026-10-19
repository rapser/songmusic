//
//  ReconcileDownloadsUseCase.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Pone de acuerdo la bandera `isDownloaded` con lo que hay realmente en disco.
///
/// `isDownloaded` es una copia cacheada de un hecho que vive en el sistema de archivos, y
/// nada garantizaba que siguieran coincidiendo. Cuando se separan —se borró
/// `Documents/Music`, una restauración trajo la base de datos sin los archivos, el sistema
/// liberó espacio— la canción queda muerta y de forma silenciosa: `PlayerUseCases.play`
/// falla con `fileNotDownloaded` y `DownloadUseCases.downloadSong` se niega a bajarla otra
/// vez con `alreadyDownloaded`, así que no hay forma de recuperarla desde la app.
///
/// Este caso de uso corre al arrancar y deja el disco como única fuente de verdad: para
/// cada canción marcada como descargada cuyo archivo no esté, limpia **solo** la bandera.
/// La metadata (artwork, duración, reproducciones) se conserva — la canción vuelve a
/// aparecer como descargable y no se pierde nada.
@MainActor
final class ReconcileDownloadsUseCase {

    private let songRepository: SongRepositoryProtocol
    private let fileStore: DownloadFileStoreProtocol

    init(songRepository: SongRepositoryProtocol, fileStore: DownloadFileStoreProtocol) {
        self.songRepository = songRepository
        self.fileStore = fileStore
    }

    /// Revisa las canciones marcadas como descargadas y corrige las que no tienen archivo.
    ///
    /// - Returns: los IDs de las canciones corregidas, vacío si todo estaba en orden.
    @discardableResult
    func execute() async throws -> [UUID] {
        let downloaded = try await songRepository.getDownloaded()
        var reconciled: [UUID] = []

        for song in downloaded where fileStore.existingFileURL(for: song.id) == nil {
            try await songRepository.updateDownloadStatus(for: song.id, isDownloaded: false)
            reconciled.append(song.id)
        }

        return reconciled
    }
}
