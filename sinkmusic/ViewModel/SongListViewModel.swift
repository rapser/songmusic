
import Foundation
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isDownloadingAll: Bool = false

    private let downloadService: DownloadService
    private let metadataService: MetadataService
    private var downloadAllTask: Task<Void, Never>?

    // Tareas de animación de progreso para suavizar actualizaciones rápidas
    private var progressAnimationTasks: [UUID: Task<Void, Never>] = [:]

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

        // Iniciar en 0% para mostrar la barra de progreso inmediatamente
        downloadProgress[song.id] = 0
        print("📥 Iniciando descarga: \(song.title)")
        Task {
            do {
                var lastLoggedPercent = -1
                var lastUIUpdatePercent = -1
                let localURL = try await downloadService.download(song: song) { [weak self] progress in
                    // Si el progreso es válido (0-1), usarlo
                    if progress >= 0 {
                        let currentPercent = Int(progress * 100)

                        // Actualizar UI solo cada 10% o al final (99%+)
                        // Esto hace que el progreso sea más visible y no tan rápido
                        if currentPercent % 10 == 0 && currentPercent != lastUIUpdatePercent || progress >= 0.99 {
                            self?.downloadProgress[song.id] = progress
                            lastUIUpdatePercent = currentPercent
                        }

                        // Solo imprimir logs cada 20% para no saturar la consola
                        if currentPercent % 20 == 0 && currentPercent != lastLoggedPercent {
                            print("📊 Descarga \(song.title): \(currentPercent)%")
                            lastLoggedPercent = currentPercent
                        }
                    }
                }

                print("✅ Descarga completada: \(song.title)")

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

                // IMPORTANTE: Marcar como descargada AL FINAL, después de extraer metadatos
                // Esto evita que la canción desaparezca de la lista antes de mostrar el progreso completo
                song.isDownloaded = true

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

                // Verificar nuevamente que la canción no esté descargada (por si se descargó mientras esperaba en la cola)
                if song.isDownloaded {
                    print("⏭️ Saltando \(song.title) - ya está descargada")
                    continue
                }

                // Iniciar en 0% para mostrar la barra de progreso inmediatamente
                downloadProgress[song.id] = 0

                do {
                    let localURL = try await downloadService.download(song: song) { [weak self] progress in
                        // Si el progreso es válido (0-1), usarlo. Si es -1, mantener el último progreso
                        if progress >= 0 {
                            self?.downloadProgress[song.id] = progress
                        }
                    }

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

                    // IMPORTANTE: Marcar como descargada AL FINAL, después de extraer metadatos
                    // Esto evita que la canción desaparezca de la lista antes de mostrar el progreso completo
                    song.isDownloaded = true

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
