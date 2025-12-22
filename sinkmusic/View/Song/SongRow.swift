//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let songQueue: [Song]
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    
    @Binding var showAddToPlaylistForSong: Song?
    @EnvironmentObject var songListViewModel: SongListViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showSongMenu = false
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Componente de información de la canción
            SongInfoView(
                title: song.title,
                artist: song.artist,
                isCurrentlyPlaying: isCurrentlyPlaying,
                isPlaying: isPlaying
            )

            Spacer(minLength: 0)

            // Componente de acción (descarga, menú, progreso)
            SongActionView(
                isDownloaded: song.isDownloaded,
                downloadProgress: songListViewModel.downloadProgress[song.id],
                showMenu: $showSongMenu,
                onDownload: {
                    songListViewModel.download(song: song, modelContext: modelContext)
                }
            )
        }
        .drawingGroup()
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? Color(white: 0.2) : (isCurrentlyPlaying ? Color.appGray.opacity(0.3) : Color.clear))
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
            onPlay()
        }
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
            Button(action: { showAddToPlaylistForSong = song }) {
                Label("Agregar a playlist", systemImage: "plus")
            }

            Button(action: {
                if isCurrentlyPlaying && isPlaying {
                    onPause()
                } else {
                    onPlay()
                }
            }) {
                Label(
                    isCurrentlyPlaying && isPlaying ? "Pausar" : "Reproducir",
                    systemImage: isCurrentlyPlaying && isPlaying ? "pause.fill" : "play.fill"
                )
            }

            Button("Cancelar", role: .cancel) {}
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    struct SongRowPreview: View {
        @State private var songForPlaylistSheet: Song?
        
        var body: some View {
            PreviewWrapper(
                songListVM: PreviewViewModels.songListVM(),
                playerVM: PreviewViewModels.playerVM(),
                modelContainer: PreviewData.container(with: [PreviewSongs.single()])
            ) {
                SongRow(
                    song: PreviewSongs.single(),
                    songQueue: [PreviewSongs.single()],
                    isCurrentlyPlaying: true,
                    isPlaying: true,
                    onPlay: { print("Play tapped") },
                    onPause: { print("Pause tapped") },
                    showAddToPlaylistForSong: $songForPlaylistSheet
                )
                .padding()
                .background(Color.appDark)
            }
        }
    }
    
    return SongRowPreview()
}
