
import Foundation
import Combine
import SwiftData

@MainActor
class SongListViewModel: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    
    private let downloadService: DownloadService
    private var cancellables = Set<AnyCancellable>()

    init(downloadService: DownloadService = DownloadService()) {
        self.downloadService = downloadService
        setupSubscriptions()
    }

    func download(song: Song, modelContext: ModelContext) {
        guard !song.isDownloaded else { return }
        downloadProgress[song.id] = -1
        Task {
            do {
                _ = try await downloadService.download(song: song)
                song.isDownloaded = true
                try modelContext.save()
                downloadProgress[song.id] = nil
            } catch {
                print("Error al descargar \(song.title): \(error.localizedDescription)")
                downloadProgress[song.id] = nil
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
