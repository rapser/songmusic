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
    static func generate(count: Int = 3, downloaded: Bool = false) -> [Song] {
        (1...count).map { i in
            Song(id: UUID(), title: "Song \(i)", artist: "Artist \(i)", fileID: "file\(i)", isDownloaded: downloaded, duration: 180 + Double(i * 10))
        }
    }
    static func single(downloaded: Bool = false) -> Song {
        Song(id: UUID(), title: "Canción de Prueba", artist: "Artista", fileID: "file123", isDownloaded: downloaded, duration: 210)
    }
}

// MARK: - Playlists de prueba
struct PreviewPlaylists {
    static func samplePlaylist() -> Playlist {
        let songs = PreviewSongs.generate(count: 5, downloaded: true)
        return Playlist(
            name: "Mi Playlist",
            description: "Mis canciones favoritas",
            songs: songs
        )
    }

    static func generate(count: Int = 3) -> [Playlist] {
        (1...count).map { i in
            let songCount = Int.random(in: 3...8)
            return Playlist(
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
    static func container(with items: [Song]) -> ModelContainer {
        do {
            let container = try ModelContainer(for: Song.self, Playlist.self,
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
                for: Song.self, Playlist.self,
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
    static func libraryVM() -> LibraryViewModel { LibraryViewModel() }
    static func songListVM() -> SongListViewModel { SongListViewModel() }
    static func playerVM(songID: UUID? = nil) -> PlayerViewModel {
        let vm = PlayerViewModel()
        if let id = songID {
            vm.currentlyPlayingID = id
            vm.isPlaying = true
            vm.songDuration = 200
            vm.playbackTime = 30
        }
        return vm
    }
}

// MARK: - Wrapper genérico
struct PreviewWrapper<Content: View>: View {
    private let content: () -> Content
    private let libraryVM: LibraryViewModel?
    private let songListVM: SongListViewModel?
    private let playerVM: PlayerViewModel?
    private let modelContainer: ModelContainer?

    init(
        libraryVM: LibraryViewModel? = nil,
        songListVM: SongListViewModel? = nil,
        playerVM: PlayerViewModel? = nil,
        modelContainer: ModelContainer? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.libraryVM = libraryVM
        self.songListVM = songListVM
        self.playerVM = playerVM
        self.modelContainer = modelContainer
        self.content = content
    }

    var body: some View {
        content()
            .environmentObject(libraryVM ?? PreviewViewModels.libraryVM())
            .environmentObject(songListVM ?? PreviewViewModels.songListVM())
            .environmentObject(playerVM ?? PreviewViewModels.playerVM())
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
