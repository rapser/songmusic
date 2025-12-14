//
//  PlaylistViewModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class PlaylistViewModel: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var showCreatePlaylist = false
    @Published var showAddToPlaylist = false
    @Published var selectedSong: Song?

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchPlaylists()
    }

    // MARK: - Fetch Playlists
    func fetchPlaylists() {
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            playlists = try modelContext.fetch(descriptor)
        } catch {
        }
    }

    // MARK: - Create Playlist
    func createPlaylist(name: String, description: String = "", coverImageData: Data? = nil) {
        let playlist = Playlist(
            name: name,
            description: description,
            coverImageData: coverImageData
        )

        modelContext.insert(playlist)

        do {
            try modelContext.save()
            fetchPlaylists()
        } catch {
        }
    }

    // MARK: - Delete Playlist
    func deletePlaylist(_ playlist: Playlist) {
        modelContext.delete(playlist)

        do {
            try modelContext.save()
            fetchPlaylists()
        } catch {
        }
    }

    // MARK: - Update Playlist
    func updatePlaylist(_ playlist: Playlist, name: String? = nil, description: String? = nil, coverImageData: Data? = nil) {
        if let name = name {
            playlist.name = name
        }
        if let description = description {
            playlist.desc = description
        }
        if let coverImageData = coverImageData {
            playlist.coverImageData = coverImageData
        }

        playlist.updatedAt = Date()

        do {
            try modelContext.save()
            fetchPlaylists()
        } catch {
        }
    }

    // MARK: - Add Song to Playlist
    func addSong(_ song: Song, to playlist: Playlist) {
        // Verificar que la canción no esté ya en la playlist
        guard !playlist.songs.contains(where: { $0.id == song.id }) else {
            return
        }

        playlist.songs.append(song)
        playlist.updatedAt = Date()

        do {
            try modelContext.save()
            fetchPlaylists()
        } catch {
        }
    }

    // MARK: - Remove Song from Playlist
    func removeSong(_ song: Song, from playlist: Playlist) {
        if let index = playlist.songs.firstIndex(where: { $0.id == song.id }) {
            playlist.songs.remove(at: index)
            playlist.updatedAt = Date()

            do {
                try modelContext.save()
                fetchPlaylists()
            } catch {
            }
        }
    }

    // MARK: - Reorder Songs
    func reorderSongs(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        playlist.songs.move(fromOffsets: source, toOffset: destination)
        playlist.updatedAt = Date()

        do {
            try modelContext.save()
            fetchPlaylists()
        } catch {
        }
    }

    // MARK: - Helper Methods
    func showAddToPlaylistSheet(for song: Song) {
        selectedSong = song
        showAddToPlaylist = true
    }
}
