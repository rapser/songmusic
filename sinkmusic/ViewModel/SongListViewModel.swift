
import Foundation
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isDownloadingAll: Bool = false

    private let downloadService: DownloadService
    private let metadataService: MetadataService
    private var downloadAllTask: Task<Void, Never>?

    // ModelContext compartido para todas las operaciones de descarga
    // Esto asegura que las actualizaciones persistan incluso si la vista se destruye
    private var sharedModelContext: ModelContext?

    init(downloadService: DownloadService = DownloadService(), metadataService: MetadataService = MetadataService()) {
        self.downloadService = downloadService
        self.metadataService = metadataService
    }

    /// Configura el ModelContext compartido (se llama una vez desde la app)
    func configure(with modelContext: ModelContext) {
        self.sharedModelContext = modelContext
    }

    func download(song: Song, modelContext: ModelContext? = nil) {
        guard !song.isDownloaded else { return }

        // Usar el contexto proporcionado o el compartido
        guard let context = modelContext ?? sharedModelContext else {
            print("❌ Error: No hay ModelContext disponible para guardar la descarga")
            return
        }

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

                try context.save()
                downloadProgress[song.id] = nil
            } catch {
                downloadProgress[song.id] = nil
            }
        }
    }

    func downloadAll(songs: [Song], modelContext: ModelContext? = nil) {
        // Usar el contexto proporcionado o el compartido
        guard let context = modelContext ?? sharedModelContext else {
            print("❌ Error: No hay ModelContext disponible para descargas masivas")
            return
        }

        // Cancelar cualquier descarga masiva anterior
        cancelDownloadAll()

        isDownloadingAll = true

        downloadAllTask = Task {
            // Aleatorizar el orden de descarga (estilo Spotify)
            // Solo incluir canciones no descargadas
            let pendingSongs = songs.filter { !$0.isDownloaded }.shuffled()

            print("📥 Iniciando descarga de \(pendingSongs.count) canciones en orden aleatorio")

            // Descargar de 1 en 1 de forma secuencial (evita saturar la red)
            for song in pendingSongs {
                // Verificar si la tarea fue cancelada
                if Task.isCancelled {
                    print("⏸️ Descarga masiva cancelada por el usuario")
                    break
                }

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

                    try context.save()
                    downloadProgress[song.id] = nil
                    print("✅ Descargada: \(song.title)")
                } catch {
                    downloadProgress[song.id] = nil
                    print("❌ Error descargando \(song.title): \(error.localizedDescription)")
                    // Continuar con la siguiente canción incluso si esta falló
                }
            }

            isDownloadingAll = false
            print("✅ Descarga masiva completada")
        }
    }

    func cancelDownloadAll() {
        downloadAllTask?.cancel()
        downloadAllTask = nil
        isDownloadingAll = false
    }

    func deleteDownload(song: Song, modelContext: ModelContext? = nil) {
        // Usar el contexto proporcionado o el compartido
        guard let context = modelContext ?? sharedModelContext else {
            print("❌ Error: No hay ModelContext disponible para eliminar descarga")
            return
        }

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
                try context.save()
            } catch {
                print("❌ Error eliminando descarga: \(error.localizedDescription)")
            }
        }
    }
}
