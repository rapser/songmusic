//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Refactored to Clean Architecture - No SwiftData dependency
//

import SwiftUI

struct SongRow: View {
    let song: SongEntity
    let songQueue: [SongEntity]
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void

    @Binding var showAddToPlaylistForSong: SongEntity?
    @Environment(DownloadViewModel.self) private var downloadViewModel

    var playlist: PlaylistEntity? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    @State private var showSongMenu = false
    @State private var showErrorAlert = false

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
                downloadProgress: downloadViewModel.downloadProgress[song.id],
                showMenu: $showSongMenu,
                onDownload: {
                    print("Download button pressed for \(song.title)")
                    Task {
                        await downloadViewModel.download(songID: song.id)
                    }
                }
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentlyPlaying ? Color.appGray.opacity(0.3) : Color.clear)
        )
        .listRowBackground(Color.appDark)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
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

            Button(action: { showAddToPlaylistForSong = song }) {
                Label("Agregar a playlist", systemImage: "plus")
            }

            // Mostrar opción de eliminar solo si estamos en una playlist
            if playlist != nil, let removeAction = onRemoveFromPlaylist {
                Button(role: .destructive, action: removeAction) {
                    Label("Eliminar de playlist", systemImage: "trash")
                }
            }

            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: downloadViewModel.downloadError) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error de descarga", isPresented: $showErrorAlert) {
            Button("OK") {
                downloadViewModel.clearDownloadError()
            }
        } message: {
            if let error = downloadViewModel.downloadError {
                Text(error)
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    struct SongRowPreview: View {
        @State private var songForPlaylistSheet: SongEntity?

        var body: some View {
            PreviewWrapper(
                playerVM: PreviewViewModels.playerVM(),
                modelContainer: PreviewData.container(with: [PreviewSongs.single()])
            ) {
                SongRow(
                    song: SongMapper.toEntity(PreviewSongs.single()),
                    songQueue: [SongMapper.toEntity(PreviewSongs.single())],
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
