//
//  SearchViewModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import SwiftData

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet {
            scheduleSearch()
        }
    }

    @Published var selectedFilter: SearchFilter = .all {
        didSet {
            scheduleSearch()
        }
    }

    @Published var filteredSongs: [Song] = []

    enum SearchFilter: String, CaseIterable {
        case all = "Todo"
        case song = "Canción"
        case artist = "Artista"
        case album = "Álbum"
    }

    private var allSongs: [Song] = []
    private var searchTask: Task<Void, Never>?

    func updateSongs(_ songs: [Song]) {
        self.allSongs = songs.filter { $0.isDownloaded }
        performSearch()
    }

    private func scheduleSearch() {
        // Cancelar búsqueda anterior
        searchTask?.cancel()

        // Programar nueva búsqueda con debounce de 300ms
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            // Verificar si la tarea fue cancelada
            guard !Task.isCancelled else { return }

            performSearch()
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            filteredSongs = []
            return
        }

        let query = searchText.lowercased()

        filteredSongs = allSongs.filter { song in
            switch selectedFilter {
            case .all:
                return song.title.lowercased().contains(query) ||
                       song.artist.lowercased().contains(query) ||
                       (song.album?.lowercased().contains(query) ?? false)
            case .song:
                return song.title.lowercased().contains(query)
            case .artist:
                return song.artist.lowercased().contains(query)
            case .album:
                return song.album?.lowercased().contains(query) ?? false
            }
        }
    }

    // Agrupar canciones por artista
    func groupedByArtist() -> [String: [Song]] {
        Dictionary(grouping: filteredSongs) { $0.artist }
    }

    // Agrupar canciones por álbum
    func groupedByAlbum() -> [String: [Song]] {
        Dictionary(grouping: filteredSongs) { $0.album ?? "Álbum Desconocido" }
    }
}
