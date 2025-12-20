//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    let song: Song  // Sin @Bindable - solo lectura
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    @Environment(\.modelContext) private var modelContext

    @StateObject private var playlistViewModel: PlaylistViewModel
    @State private var showAddToPlaylist = false
    @State private var showSongMenu = false
    @State private var isPressed = false

    // Snapshot de propiedades para comparación
    private let songId: UUID
    private let songTitle: String
    private let songArtist: String
    private let songIsDownloaded: Bool

    init(song: Song) {
        self.song = song
        self.songId = song.id
        self.songTitle = song.title
        self.songArtist = song.artist
        self.songIsDownloaded = song.isDownloaded
        self._playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: song.modelContext!))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Componente de información de la canción
            SongInfoView(
                title: songTitle,
                artist: songArtist,
                isCurrentlyPlaying: playerViewModel.currentlyPlayingID == songId,
                isPlaying: playerViewModel.isPlaying
            )

            Spacer(minLength: 0)

            // Componente de acción (descarga, menú, progreso)
            SongActionView(
                isDownloaded: songIsDownloaded,
                downloadProgress: songListViewModel.downloadProgress[songId],
                showMenu: $showSongMenu,
                onDownload: {
                    songListViewModel.download(song: song, modelContext: modelContext)
                }
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? Color(white: 0.2) : (playerViewModel.currentlyPlayingID == songId ? Color.appGray.opacity(0.3) : Color.clear))
        )
        .listRowBackground(Color.appDark)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.linear(duration: 0.05)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.linear(duration: 0.05)) {
                        isPressed = false
                    }
                }
        )
        .onTapGesture {
            if songIsDownloaded && songListViewModel.downloadProgress[songId] == nil {
                playerViewModel.play(song: song)
            }
        }
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
            // Agregar a playlist (siempre disponible para canciones descargadas)
            Button(action: { showAddToPlaylist = true }) {
                Label("Agregar a playlist", systemImage: "plus")
            }

            Button(action: {
                if playerViewModel.currentlyPlayingID == songId {
                    playerViewModel.pause()
                } else {
                    playerViewModel.play(song: song)
                }
            }) {
                Label(
                    playerViewModel.currentlyPlayingID == songId && playerViewModel.isPlaying ? "Pausar" : "Reproducir",
                    systemImage: playerViewModel.currentlyPlayingID == songId && playerViewModel.isPlaying ? "pause.fill" : "play.fill"
                )
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
        songListVM: PreviewViewModels.songListVM(),
        modelContainer: PreviewData.container(with: [PreviewSongs.single()])
    ) {
        SongRow(song: PreviewSongs.single())
            .padding()
            .background(Color.black)
    }
}
