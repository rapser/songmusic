//
//  AddSongsToPlaylistView.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  No SwiftData dependency
//

import SwiftUI

struct AddSongsToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel

    let playlist: PlaylistUIModel

    // Paginación
    @State private var displayedSongsCount = 30 // Mostrar 30 canciones inicialmente
    private let itemsPerPage = 30

    // Búsqueda
    @State private var searchText = ""

    private var availableSongs: [SongUIModel] {
        // Filtrar solo canciones descargadas que NO están en ninguna playlist
        let baseSongs = libraryViewModel.songs.filter { song in
            song.isDownloaded && !viewModel.isSongInAnyPlaylist(songID: song.id)
        }

        // Aplicar filtro de búsqueda si hay texto
        let filteredSongs: [SongUIModel]
        if searchText.isEmpty {
            filteredSongs = baseSongs
        } else {
            filteredSongs = baseSongs.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Ordenar alfabéticamente por título
        return filteredSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var displayedSongs: [SongUIModel] {
        Array(availableSongs.prefix(displayedSongsCount))
    }

    private var hasMoreSongs: Bool {
        displayedSongsCount < availableSongs.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)
                mainContent
            }
            .navigationTitle("Agregar a esta playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchBar
            contentView
        }
    }

    private var searchBar: some View {
        SearchBar(text: $searchText, placeholder: "Buscar por título o artista")
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private var contentView: some View {
        if availableSongs.isEmpty {
            emptyStateView
        } else {
            songsListView
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if searchText.isEmpty {
            EmptyAvailableSongsView()
        } else {
            SearchEmptyView(searchText: searchText)
        }
    }

    private var songsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedSongs) { song in
                    songRowItem(song: song)
                }

                if hasMoreSongs {
                    loadMoreIndicator
                }
            }
        }
    }

    private func songRowItem(song: SongUIModel) -> some View {
        VStack(spacing: 0) {
            AddSongRow(song: song) {
                Task {
                    await viewModel.addSongToPlaylist(songID: song.id, playlistID: playlist.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))
        }
    }

    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Spacer()
        }
        .padding()
        .onAppear {
            loadMoreSongs()
        }
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .foregroundColor(.white)
        }
    }

    private func loadMoreSongs() {
        guard hasMoreSongs else { return }
        displayedSongsCount += itemsPerPage
    }
}
