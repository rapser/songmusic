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

    let playlist: PlaylistEntity

    // Paginación
    @State private var displayedSongsCount = 30 // Mostrar 30 canciones inicialmente
    private let itemsPerPage = 30

    // Búsqueda
    @State private var searchText = ""

    private var availableSongs: [SongEntity] {
        // Filtrar solo canciones descargadas que NO están en ninguna playlist
        let baseSongs = libraryViewModel.songs.filter { song in
            song.isDownloaded && !viewModel.isSongInAnyPlaylist(songID: song.id)
        }

        // Aplicar filtro de búsqueda si hay texto
        let filteredSongs: [SongEntity]
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

    private var displayedSongs: [SongEntity] {
        Array(availableSongs.prefix(displayedSongsCount))
    }

    private var hasMoreSongs: Bool {
        displayedSongsCount < availableSongs.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Barra de búsqueda
                    SearchBar(text: $searchText, placeholder: "Buscar por título o artista")
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if availableSongs.isEmpty {
                        if searchText.isEmpty {
                            EmptyAvailableSongsView()
                        } else {
                            SearchEmptyView(searchText: searchText)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(displayedSongs) { song in
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

                                // Trigger para cargar más canciones
                                if hasMoreSongs {
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
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agregar a esta playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func loadMoreSongs() {
        guard hasMoreSongs else { return }
        displayedSongsCount += itemsPerPage
    }
}
