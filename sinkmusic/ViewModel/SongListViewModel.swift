
import Foundation
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var downloadError: String? = nil

    // SOLID: Dependency Inversion - depende de abstracciones, no de implementaciones concretas
    private let downloadService: GoogleDriveServiceProtocol
    private let metadataService: MetadataServiceProtocol

    // Tareas de animación de progreso para suavizar actualizaciones rápidas
    private var progressAnimationTasks: [UUID: Task<Void, Never>] = [:]

    // ModelContext compartido para todas las operaciones de descarga
    // Esto asegura que las actualizaciones persistan incluso si la vista se destruye
    private var sharedModelContext: ModelContext?

    init(
        downloadService: GoogleDriveServiceProtocol = GoogleDriveService(),
        metadataService: MetadataServiceProtocol = MetadataService()
    ) {
        self.downloadService = downloadService
        self.metadataService = metadataService
    }

    /// Configura el ModelContext compartido (se llama una vez desde la app)
    func configure(with modelContext: ModelContext) {
        self.sharedModelContext = modelContext
    }

    func download(song: Song, modelContext: ModelContext? = nil) {
        guard let context = modelContext ?? sharedModelContext else {
            print("❌ Error: No hay ModelContext disponible para guardar la descarga")
            return
        }

        Task {
            await performDownload(for: song, context: context)
        }
    }

    /// Función centralizada y reutilizable para descargar una canción.
    private func performDownload(for song: Song, context: ModelContext) async {
        // Verificar nuevamente que la canción no esté descargada
        guard !song.isDownloaded else {
            print("⏭️ Saltando \(song.title) - ya está descargada")
            return
        }

        // Iniciar en 0% para mostrar la barra de progreso inmediatamente
        downloadProgress[song.id] = 0
        print("📥 Iniciando descarga: \(song.title)")

        do {
            let localURL = try await downloadService.download(song: song) { [weak self] progress in
                if progress >= 0 {
                    self?.downloadProgress[song.id] = progress
                }
            }
            print("✅ Descarga completada: \(song.title)")

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

            song.isDownloaded = true
            try context.save()
            downloadProgress[song.id] = 1.0 // Mostrar 100% completado
            print("💾 Guardada: \(song.title)")

            // Mantener barra en 100% por 0.5 segundos para feedback visual
            try? await Task.sleep(nanoseconds: 500_000_000)
            downloadProgress[song.id] = nil

        } catch {
            downloadProgress[song.id] = nil
            downloadError = "Error descargando \(song.title): \(error.localizedDescription)"
            print("❌ \(downloadError!)")
            // La función termina aquí, y el bucle en `downloadAll` continuará
        }
    }

    func clearDownloadError() {
        downloadError = nil
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
                downloadError = "Error eliminando descarga: \(error.localizedDescription)"
                print("❌ \(downloadError!)")
            }
        }
    }

    deinit {
        // Cancelar todas las tareas de animación de progreso
        for (_, task) in progressAnimationTasks {
            task.cancel()
        }
        progressAnimationTasks.removeAll()

        print("🗑️ SongListViewModel deinicializado - recursos liberados")
    }
}
