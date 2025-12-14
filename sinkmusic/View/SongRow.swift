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
                    .foregroundColor(.textGray)
            }
            Spacer(minLength: 0)

            if let progress = songListViewModel.downloadProgress[song.id] {
                if progress < 0 {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 100)
                } else {
                    VStack {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .appPurple))
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100)
                }
            } else if song.isDownloaded {
                HStack(spacing: 4) {
                    Button(action: {
                        playerViewModel.play(song: song)
                    }) {
                        Image(systemName: playerViewModel.currentlyPlayingID == song.id && playerViewModel.isPlaying
                              ? "pause.circle.fill"
                              : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appPurple)
                            .frame(width: 44, height: 44)
                    }

                    // Botón de tres puntos horizontales (menú) - estilo Spotify
                    Button(action: {
                        showSongMenu = true
                    }) {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.textGray)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color.textGray)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color.textGray)
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .padding(.trailing, -8)
            } else {
                Button(action: {
                    songListViewModel.download(song: song, modelContext: modelContext)
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.appPurple)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.appDark)
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
            // Agregar a playlist (siempre disponible para canciones descargadas)
            Button(action: { showAddToPlaylist = true }) {
                Label("Agregar a playlist", systemImage: "plus")
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

            // Opción para eliminar la descarga
            Button(role: .destructive, action: {
                songListViewModel.deleteDownload(song: song, modelContext: modelContext)
            }) {
                Label("Eliminar descarga", systemImage: "trash")
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
