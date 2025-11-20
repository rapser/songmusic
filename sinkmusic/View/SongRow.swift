//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    @Bindable var song: Song
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    @Environment(\.modelContext) private var modelContext

    @StateObject private var playlistViewModel: PlaylistViewModel
    @State private var showAddToPlaylist = false
    @State private var showSongMenu = false

    init(song: Song) {
        self._song = Bindable(wrappedValue: song)
        // Note: modelContext will be injected via environment
        self._playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: song.modelContext!))
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.spotifyLightGray)
            }
            Spacer()

            if let progress = songListViewModel.downloadProgress[song.id] {
                if progress < 0 {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 100)
                } else {
                    VStack {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .spotifyGreen))
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100)
                }
            } else if song.isDownloaded {
                HStack(spacing: 8) {
                    Button(action: {
                        playerViewModel.play(song: song)
                    }) {
                        Image(systemName: playerViewModel.currentlyPlayingID == song.id && playerViewModel.isPlaying
                              ? "pause.circle.fill"
                              : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.spotifyGreen)
                            .frame(width: 44, height: 44)
                    }

                    // Botón de tres puntos verticales (menú)
                    Button(action: {
                        showSongMenu = true
                    }) {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Color.spotifyLightGray)
                                .frame(width: 3, height: 3)
                            Circle()
                                .fill(Color.spotifyLightGray)
                                .frame(width: 3, height: 3)
                            Circle()
                                .fill(Color.spotifyLightGray)
                                .frame(width: 3, height: 3)
                        }
                        .frame(width: 32, height: 32)
                    }
                }
            } else {
                Button(action: {
                    songListViewModel.download(song: song, modelContext: modelContext)
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.spotifyGreen)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.spotifyBlack)
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
            // Solo mostrar "Agregar a playlist" si la canción tiene duración (ya se reprodujo)
            if song.duration != nil {
                Button(action: { showAddToPlaylist = true }) {
                    Label("Agregar a playlist", systemImage: "plus")
                }
            }

            Button(action: {
                if playerViewModel.currentlyPlayingID == song.id {
                    playerViewModel.pause()
                } else {
                    playerViewModel.play(song: song)
                }
            }) {
                Label(
                    playerViewModel.currentlyPlayingID == song.id && playerViewModel.isPlaying ? "Pausar" : "Reproducir",
                    systemImage: playerViewModel.currentlyPlayingID == song.id && playerViewModel.isPlaying ? "pause.fill" : "play.fill"
                )
            }

            // Mensaje si no tiene duración
            if song.duration == nil {
                Button(action: {}) {
                    Label("Reproduce primero para agregar a playlist", systemImage: "info.circle")
                }
                .disabled(true)
            }

            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistView(viewModel: playlistViewModel, song: song)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        songListVM: PreviewViewModels.songListVM(),
        modelContainer: PreviewData.container(with: [PreviewSongs.single()])
    ) {
        SongRow(song: PreviewSongs.single())
            .padding()
            .background(Color.black)
    }
}
