
import Foundation
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isDownloadingAll: Bool = false

    private let downloadService: DownloadService
    private let metadataService: MetadataService
    private var downloadAllTask: Task<Void, Never>?

    init(downloadService: DownloadService = DownloadService(), metadataService: MetadataService = MetadataService()) {
        self.downloadService = downloadService
        self.metadataService = metadataService
    }

    func download(song: Song, modelContext: ModelContext) {
        guard !song.isDownloaded else { return }
        downloadProgress[song.id] = -1
        Task {
            do {
                let localURL = try await downloadService.download(song: song) { [weak self] progress in
                    self?.downloadProgress[song.id] = progress
                }
                song.isDownloaded = true

                // Extraer metadatos del archivo descargado
                if let metadata = await metadataService.extractMetadata(from: localURL) {
                    song.title = metadata.title
                    song.artist = metadata.artist
                    song.album = metadata.album
                    song.author = metadata.author
                    song.duration = metadata.duration
                    song.artworkData = metadata.artwork
                    song.artworkThumbnail = metadata.artworkThumbnail
                    song.artworkMediumThumbnail = metadata.artworkMediumThumbnail
                }

                try modelContext.save()
                downloadProgress[song.id] = nil
            } catch {
                downloadProgress[song.id] = nil
            }
        }
    }

    func downloadAll(songs: [Song], modelContext: ModelContext) {
        // Cancelar cualquier descarga masiva anterior
        cancelDownloadAll()

        isDownloadingAll = true

        downloadAllTask = Task {
            for song in songs {
                // Verificar si la tarea fue cancelada
                if Task.isCancelled {
                    break
                }

                // Solo descargar si no está descargada
                guard !song.isDownloaded else { continue }

                downloadProgress[song.id] = -1

                do {
                    let localURL = try await downloadService.download(song: song) { [weak self] progress in
                        self?.downloadProgress[song.id] = progress
                    }
                    song.isDownloaded = true

                    // Extraer metadatos del archivo descargado
                    if let metadata = await metadataService.extractMetadata(from: localURL) {
                        song.title = metadata.title
                        song.artist = metadata.artist
                        song.album = metadata.album
                        song.author = metadata.author
                        song.duration = metadata.duration
                        song.artworkData = metadata.artwork
                        song.artworkThumbnail = metadata.artworkThumbnail
                        song.artworkMediumThumbnail = metadata.artworkMediumThumbnail
                    }

                    try modelContext.save()
                    downloadProgress[song.id] = nil
                } catch {
                    downloadProgress[song.id] = nil
                }
            }

            isDownloadingAll = false
        }
    }

    func cancelDownloadAll() {
        downloadAllTask?.cancel()
        downloadAllTask = nil
        isDownloadingAll = false
    }

    func deleteDownload(song: Song, modelContext: ModelContext) {
        Task {
            do {
                // Eliminar el archivo descargado
                try downloadService.deleteDownload(for: song.id)

                // Resetear los datos de la canción
                song.isDownloaded = false
                song.duration = nil
                song.artworkData = nil
                song.album = nil
                song.author = nil

                // Guardar cambios
                try modelContext.save()
            } catch {
            }
        }
    }
}
