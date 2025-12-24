//
//  AddSongsToPlaylistView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 12/21/25.
//

import SwiftUI
import SwiftData

struct AddSongsToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PlaylistViewModel
    let playlist: Playlist

    // Query for all downloaded songs
    @Query private var allSongs: [Song]

    // Paginación
    @State private var displayedSongsCount = 30 // Mostrar 30 canciones inicialmente
    private let itemsPerPage = 30

    // Búsqueda
    @State private var searchText = ""

    private var availableSongs: [Song] {
        // Filtrar solo canciones descargadas que NO están en NINGUNA playlist
        let baseSongs = allSongs.filter { $0.isDownloaded && $0.playlists.isEmpty }

        // Aplicar filtro de búsqueda si hay texto
        let filteredSongs: [Song]
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

    private var displayedSongs: [Song] {
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
                                            viewModel.addSong(song, to: playlist)
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
