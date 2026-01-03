//
//  PlaylistDetailView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel

    let playlist: PlaylistEntity
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showAddSongsSheet = false
    @State private var songForPlaylistSheet: SongEntity?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    // Header with Cover
                    VStack(spacing: 16) {
                        // Cover Image
                        ZStack {
                            if let coverData = playlist.coverImageData,
                               let uiImage = UIImage(data: coverData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipped()
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.6, brightness: 0.5),
                                        Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.7, brightness: 0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.6))
                                )
                            }
                        }
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                        // Playlist Info
                        VStack(spacing: 8) {
                            Text(playlist.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            if !playlist.desc.isEmpty {
                                Text(playlist.desc)
                                    .font(.system(size: 14))
                                    .foregroundColor(.textGray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }

                            Text("\(playlist.songCount) canciones • \(playlist.formattedDuration)")
                                .font(.system(size: 13))
                                .foregroundColor(.textGray)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Action Buttons
                    HStack(spacing: 16) {
                        // Play All Button
                        if !playlist.songs.isEmpty {
                            Button(action: { playAll() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16))
                                    Text("Reproducir")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.appPurple)
                                .cornerRadius(24)
                            }
                        }

                        // Add Songs Button
                        Button(action: { showAddSongsSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16))
                                Text("Agregar")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(24)
                        }

                        // Edit Button
                        Button(action: { showEditSheet = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.textGray)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Songs List
                    if playlist.songs.isEmpty {
                        EmptyPlaylistSongsView(onAddSongs: { showAddSongsSheet = true })
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(playlist.songs) { song in
                                SongRow(
                                    song: song,
                                    songQueue: playlist.songs,
                                    isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
                                    isPlaying: playerViewModel.isPlaying,
                                    onPlay: {
                                        if let url = song.localURL {
                                            playerViewModel.play(song: song, from: url, in: playlist.songs)
                                        }
                                    },
                                    onPause: {
                                        playerViewModel.pause()
                                    },
                                    showAddToPlaylistForSong: $songForPlaylistSheet,
                                    playlist: playlist,
                                    onRemoveFromPlaylist: {
                                        viewModel.removeSong(song, from: playlist)
                                    }
                                )

                                if song.id != playlist.songs.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 20)
                                }
                            }
                            .onMove { source, destination in
                                viewModel.reorderSongs(in: playlist, from: source, to: destination)
                            }
                        }
                        .environment(\.editMode, $editMode)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showAddSongsSheet) {
            AddSongsToPlaylistView(viewModel: viewModel, playlist: playlist)
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(viewModel: viewModel, song: song)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !playlist.songs.isEmpty {
                    Button(editMode == .active ? "Listo" : "Editar") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                    .foregroundColor(.appPurple)
                }
            }
        }
        .confirmationDialog("Opciones de playlist", isPresented: $showEditSheet) {
            Button("Editar información") {
                // TODO: Implement edit functionality
            }
            Button("Eliminar playlist", role: .destructive) {
                showDeleteAlert = true
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("¿Eliminar playlist?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                viewModel.deletePlaylist(playlist)
                dismiss()
            }
        } message: {
            Text("Esta acción no se puede deshacer")
        }
    }

    private func playAll() {
        guard let firstSong = playlist.songs.first,
              let url = firstSong.localURL else { return }
        playerViewModel.play(song: firstSong, from: url, in: playlist.songs)
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(
            playlist: PreviewPlaylists.samplePlaylist(),
            modelContext: PreviewContainer.shared.mainContext
        )
        .environmentObject(PreviewViewModels.playerVM(songID: UUID()))
        .environmentObject(PreviewViewModels.songListVM())
    }
}

