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

    private var availableSongs: [Song] {
        // Filtrar solo canciones descargadas que NO están en NINGUNA playlist
        // Ordenadas alfabéticamente por título
        return allSongs
            .filter { $0.isDownloaded && $0.playlists.isEmpty }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
                    if availableSongs.isEmpty {
                        EmptyAvailableSongsView()
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
