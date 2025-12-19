//
//  AddToPlaylistView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI
import SwiftData

struct AddToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]) private var playlists: [Playlist]
    @ObservedObject var viewModel: PlaylistViewModel
    let song: Song

    @State private var searchText = ""

    var filteredPlaylists: [Playlist] {
        if searchText.isEmpty {
            return playlists
        } else {
            return playlists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textGray)

                        TextField("Buscar playlist", text: $searchText)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textGray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.appGray)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    // New Playlist Button
                    Button(action: {
                        viewModel.showCreatePlaylist = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appGray)
                                    .frame(width: 50, height: 50)

                                Image(systemName: "plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Text("Nueva playlist")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)

                    // Playlists List
                    if filteredPlaylists.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundColor(.textGray)

                            Text(searchText.isEmpty ? "No hay playlists" : "No se encontraron playlists")
                                .font(.system(size: 16))
                                .foregroundColor(.textGray)

                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredPlaylists, id: \.id) { playlist in
                                    PlaylistSelectRow(
                                        playlist: playlist,
                                        song: song,
                                        isAdded: playlist.songs.contains(where: { $0.id == song.id })
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        addToPlaylist(playlist)
                                    }

                                    if playlist.id != filteredPlaylists.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 80)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Agregar a playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreatePlaylist) {
            CreatePlaylistView()
                .environment(\.modelContext, modelContext)
        }
    }

    private func addToPlaylist(_ playlist: Playlist) {
        viewModel.addSong(song, to: playlist)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Auto-dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

#Preview {
    AddToPlaylistView(
        viewModel: PlaylistViewModel(modelContext: PreviewContainer.shared.mainContext),
        song: PreviewSongs.single()
    )
}
