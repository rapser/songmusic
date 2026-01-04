//
//  PreviewData.swift
//  sinkmusic
//
//  Created by miguel tomairo on 7/09/25.
//

import SwiftUI
import SwiftData

// MARK: - Canciones de prueba
struct PreviewSongs {
    static func generate(count: Int = 3, downloaded: Bool = false) -> [SongDTO] {
        (1...count).map { i in
            SongDTO(id: UUID(), title: "Song \(i)", artist: "Artist \(i)", fileID: "file\(i)", isDownloaded: downloaded, duration: 180 + Double(i * 10))
        }
    }
    static func single(downloaded: Bool = false) -> SongDTO {
        SongDTO(id: UUID(), title: "Canción de Prueba", artist: "Artista", fileID: "file123", isDownloaded: downloaded, duration: 210)
    }
}

// MARK: - Playlists de prueba
struct PreviewPlaylists {
    static func samplePlaylist() -> PlaylistDTO {
        let songs = PreviewSongs.generate(count: 5, downloaded: true)
        return PlaylistDTO(
            name: "Mi Playlist",
            description: "Mis canciones favoritas",
            songs: songs
        )
    }

    static func generate(count: Int = 3) -> [PlaylistDTO] {
        (1...count).map { i in
            let songCount = Int.random(in: 3...8)
            return PlaylistDTO(
                name: "Playlist \(i)",
                description: "Descripción de la playlist \(i)",
                songs: PreviewSongs.generate(count: songCount, downloaded: true)
            )
        }
    }
}

// MARK: - Container de prueba
@MainActor
struct PreviewData {
    static func container(with items: [SongDTO]) -> ModelContainer {
        do {
            let container = try ModelContainer(for: SongDTO.self, PlaylistDTO.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = container.mainContext
            items.forEach { context.insert($0) }
            return container
        } catch {
            fatalError("❌ Failed to create container: \(error)")
        }
    }
}

// MARK: - PreviewContainer singleton
@MainActor
struct PreviewContainer {
    static let shared = PreviewContainer()

    let container: ModelContainer
    var mainContext: ModelContext {
        container.mainContext
    }

    private init() {
        do {
            container = try ModelContainer(
                for: SongDTO.self, PlaylistDTO.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            // Seed with sample data
            let songs = PreviewSongs.generate(count: 10, downloaded: true)
            songs.forEach { container.mainContext.insert($0) }

            let playlists = PreviewPlaylists.generate(count: 3)
            playlists.forEach { container.mainContext.insert($0) }
        } catch {
            fatalError("❌ Failed to create preview container: \(error)")
        }
    }
}

// MARK: - ViewModels de prueba
@MainActor
struct PreviewViewModels {
    // Configurar DIContainer con el PreviewContainer
    private static func setupDI() {
        let container = PreviewContainer.shared.container
        DIContainer.shared.configure(with: container.mainContext)
    }

    static func libraryVM() -> LibraryViewModel {
        setupDI()
        return LibraryViewModel(libraryUseCases: DIContainer.shared.libraryUseCases)
    }

    static func playerVM(songID: UUID? = nil) -> PlayerViewModel {
        setupDI()
        let vm = PlayerViewModel(
            playerUseCases: DIContainer.shared.playerUseCases,
            songRepository: DIContainer.shared.songRepository
        )
        if let id = songID {
            vm.currentlyPlayingID = id
            vm.isPlaying = true
            vm.songDuration = 200
            vm.playbackTime = 30
        }
        return vm
    }

    static func playlistVM() -> PlaylistViewModel {
        setupDI()
        return PlaylistViewModel(playlistUseCases: DIContainer.shared.playlistUseCases)
    }

    static func searchVM() -> SearchViewModel {
        setupDI()
        return SearchViewModel(searchUseCases: DIContainer.shared.searchUseCases)
    }

    static func equalizerVM() -> EqualizerViewModel {
        setupDI()
        return EqualizerViewModel(equalizerUseCases: DIContainer.shared.equalizerUseCases)
    }

    static func metadataVM() -> MetadataCacheViewModel {
        return MetadataCacheViewModel()
    }

    static func downloadVM() -> DownloadViewModel {
        setupDI()
        return DownloadViewModel(downloadUseCases: DIContainer.shared.downloadUseCases)
    }
}

// MARK: - Wrapper genérico
struct PreviewWrapper<Content: View>: View {
    private let content: () -> Content
    private let libraryVM: LibraryViewModel?
    private let playerVM: PlayerViewModel?
    private let playlistVM: PlaylistViewModel?
    private let searchVM: SearchViewModel?
    private let equalizerVM: EqualizerViewModel?
    private let downloadVM: DownloadViewModel?
    private let metadataVM: MetadataCacheViewModel?
    private let modelContainer: ModelContainer?

    init(
        libraryVM: LibraryViewModel? = nil,
        playerVM: PlayerViewModel? = nil,
        playlistVM: PlaylistViewModel? = nil,
        searchVM: SearchViewModel? = nil,
        equalizerVM: EqualizerViewModel? = nil,
        downloadVM: DownloadViewModel? = nil,
        metadataVM: MetadataCacheViewModel? = nil,
        modelContainer: ModelContainer? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.libraryVM = libraryVM
        self.playerVM = playerVM
        self.playlistVM = playlistVM
        self.searchVM = searchVM
        self.equalizerVM = equalizerVM
        self.downloadVM = downloadVM
        self.metadataVM = metadataVM
        self.modelContainer = modelContainer
        self.content = content
    }

    var body: some View {
        content()
            .environment(libraryVM ?? PreviewViewModels.libraryVM())
            .environment(playerVM ?? PreviewViewModels.playerVM())
            .environment(playlistVM ?? PreviewViewModels.playlistVM())
            .environment(searchVM ?? PreviewViewModels.searchVM())
            .environment(equalizerVM ?? PreviewViewModels.equalizerVM())
            .environment(downloadVM ?? PreviewViewModels.downloadVM())
            .environment(metadataVM ?? PreviewViewModels.metadataVM())
            .ifLet(modelContainer) { view, container in
                view.modelContainer(container)
            }
    }
}

extension View {
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value { transform(self, value) } else { self }
    }
}
