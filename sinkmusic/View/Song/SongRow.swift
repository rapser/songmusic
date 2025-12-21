//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let songQueue: [Song] // La cola de reproducción a la que pertenece esta canción
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

    init(song: Song, songQueue: [Song]) {
        self.song = song
        self.songQueue = songQueue
        self.songId = song.id
        self.songTitle = song.title
        self.songArtist = song.artist
        self.songIsDownloaded = song.isDownloaded
        
        // Comprobar si modelContext existe antes de usarlo
        if let context = song.modelContext {
            self._playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: context))
        } else {
            // Fallback si no hay contexto (ej. en previews con datos mockeados)
            // Aquí podrías decidir lanzar un error o usar un contexto temporal
            // Por simplicidad, usamos un initializer que podría fallar en un caso real sin contexto
            // pero para previews funciona.
            self._playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: .init(try! .init(for: Song.self, Playlist.self))))
        }
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
            if songIsDownloaded && songListViewModel.downloadProgress[songId] == nil,
               let url = song.localURL {
                playerViewModel.play(song: song, from: url, in: songQueue)
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
                } else if let url = song.localURL {
                    playerViewModel.play(song: song, from: url, in: songQueue)
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
        SongRow(song: PreviewSongs.single(), songQueue: [PreviewSongs.single()])
            .padding()
            .background(Color.black)
    }
}
