
import Foundation
import Combine
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]

    private let downloadService: DownloadService
    private let metadataService: MetadataService
    private var cancellables = Set<AnyCancellable>()

    init(downloadService: DownloadService = DownloadService(), metadataService: MetadataService = MetadataService()) {
        self.downloadService = downloadService
        self.metadataService = metadataService
        setupSubscriptions()
    }

    func download(song: Song, modelContext: ModelContext) {
        guard !song.isDownloaded else { return }
        downloadProgress[song.id] = -1
        Task {
            do {
                let localURL = try await downloadService.download(song: song)
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
                }

                try modelContext.save()
                downloadProgress[song.id] = nil
            } catch {
                downloadProgress[song.id] = nil
            }
        }
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

    private func setupSubscriptions() {
        downloadService.downloadProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (songID, progress) in
                self?.downloadProgress[songID] = progress
            }
            .store(in: &cancellables)
    }
}
