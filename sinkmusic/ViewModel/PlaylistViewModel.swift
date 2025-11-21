//
//  PlaylistViewModel.swift
//  sinkmusic
//
//  Created by Claude Code
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
            print("✅ Fetched \(playlists.count) playlists")
        } catch {
            print("❌ Error fetching playlists: \(error.localizedDescription)")
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
            print("✅ Playlist '\(name)' created successfully")
        } catch {
            print("❌ Error creating playlist: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Playlist
    func deletePlaylist(_ playlist: Playlist) {
        modelContext.delete(playlist)

        do {
            try modelContext.save()
            fetchPlaylists()
            print("✅ Playlist deleted")
        } catch {
            print("❌ Error deleting playlist: \(error.localizedDescription)")
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
            print("✅ Playlist updated")
        } catch {
            print("❌ Error updating playlist: \(error.localizedDescription)")
        }
    }

    // MARK: - Add Song to Playlist
    func addSong(_ song: Song, to playlist: Playlist) {
        // Verificar que la canción no esté ya en la playlist
        guard !playlist.songs.contains(where: { $0.id == song.id }) else {
            print("⚠️ Song already in playlist")
            return
        }

        playlist.songs.append(song)
        playlist.updatedAt = Date()

        do {
            try modelContext.save()
            fetchPlaylists()
            print("✅ Song '\(song.title)' added to '\(playlist.name)'")
        } catch {
            print("❌ Error adding song to playlist: \(error.localizedDescription)")
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
                print("✅ Song removed from playlist")
            } catch {
                print("❌ Error removing song: \(error.localizedDescription)")
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
            print("✅ Songs reordered")
        } catch {
            print("❌ Error reordering songs: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods
    func showAddToPlaylistSheet(for song: Song) {
        selectedSong = song
        showAddToPlaylist = true
    }
}
