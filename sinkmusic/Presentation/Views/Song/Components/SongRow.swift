//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Refactored to Clean Architecture - No SwiftData dependency
//

import SwiftUI

struct SongRow: View {
    let song: SongUI
    let songQueue: [SongUI]
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    /// true cuando el List está en modo edición (reordenamiento activo).
    /// Oculta el botón de acción para que el handle de drag no comprima el layout.
    var isReordering: Bool = false
    let onPlay: () -> Void
    let onPause: () -> Void

    @Binding var showAddToPlaylistForSong: SongUI?
    @Environment(DownloadViewModel.self) private var downloadViewModel

    var playlist: PlaylistUI? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    @State private var showSongMenu = false
    @State private var showErrorAlert = false

    var body: some View {
        HStack(spacing: 12) {
            // Área principal: tap = reproducir (estilo Spotify).
            SongInfoView(
                title: song.title,
                artist: song.artist,
                isCurrentlyPlaying: isCurrentlyPlaying,
                isPlaying: isPlaying
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isReordering {
                    onPlay()
                }
            }

            Spacer(minLength: 0)

            // Tres puntos: abren confirmationDialog (evita advertencias de Menu en List).
            if !isReordering {
                SongActionView(
                    isDownloaded: song.isDownloaded,
                    downloadProgress: downloadViewModel.downloadProgress[song.id],
                    showMenu: $showSongMenu,
                    onDownload: {
                        Task {
                            await downloadViewModel.download(songID: song.id)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentlyPlaying ? Color.appGray.opacity(0.3) : Color.clear)
        )
        .listRowBackground(Color.appDark)
        .confirmationDialog("Opciones", isPresented: $showSongMenu, titleVisibility: .hidden) {
            Button {
                if isCurrentlyPlaying && isPlaying {
                    onPause()
                } else {
                    onPlay()
                }
            } label: {
                Label(
                    isCurrentlyPlaying && isPlaying ? "Pausar" : "Reproducir",
                    systemImage: isCurrentlyPlaying && isPlaying ? "pause.fill" : "play.fill"
                )
            }
            Button {
                showAddToPlaylistForSong = song
            } label: {
                Label("Agregar a playlist", systemImage: "plus")
            }
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

