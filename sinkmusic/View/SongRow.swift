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
    @State private var isPressed = false

    init(song: Song) {
        self._song = Bindable(wrappedValue: song)
        self._playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: song.modelContext!))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Componente de información de la canción
            SongInfoView(
                title: song.title,
                artist: song.artist,
                isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
                isPlaying: playerViewModel.isPlaying
            )

            Spacer(minLength: 0)

            // Componente de acción (descarga, menú, progreso)
            SongActionView(
                song: song,
                downloadProgress: songListViewModel.downloadProgress[song.id],
                showMenu: $showSongMenu,
                onDownload: {
                    songListViewModel.download(song: song, modelContext: modelContext)
                }
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? Color(white: 0.2) : (playerViewModel.currentlyPlayingID == song.id ? Color.appGray.opacity(0.3) : Color.clear))
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
            if song.isDownloaded && songListViewModel.downloadProgress[song.id] == nil {
                playerViewModel.play(song: song)
            }
        }
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

            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistView(viewModel: playlistViewModel, song: song)
        }
    }
}

// MARK: - Componentes Modulares

/// Componente optimizado para mostrar la información de la canción
private struct SongInfoView: View {
    let title: String
    let artist: String
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isCurrentlyPlaying {
                    PlayingBarsIndicator(isPlaying: isPlaying)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(isCurrentlyPlaying ? .appPurple : .white)
                    .lineLimit(1)
            }

            Text(artist)
                .font(.subheadline)
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        .drawingGroup()
    }
}

/// Componente optimizado para las acciones de la canción (descarga, menú, progreso)
private struct SongActionView: View {
    let song: Song
    let downloadProgress: Double?
    @Binding var showMenu: Bool
    let onDownload: () -> Void

    var body: some View {
        Group {
            if let progress = downloadProgress {
                // Siempre mostrar la barra de progreso (0% a 100%)
                DownloadProgressView(progress: progress)
            } else if song.isDownloaded {
                MenuButton(showMenu: $showMenu)
            } else {
                DownloadButton(action: onDownload)
            }
        }
    }
}

/// Botón de menú de tres puntos
private struct MenuButton: View {
    @Binding var showMenu: Bool

    var body: some View {
        Button(action: { showMenu = true }) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.textGray)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, -8)
    }
}

/// Botón de descarga
private struct DownloadButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 24))
                .foregroundColor(.appPurple)
                .frame(width: 44, height: 44)
        }
    }
}

/// Vista de progreso de descarga
private struct DownloadProgressView: View {
    let progress: Double

    var body: some View {
        VStack {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .appPurple))
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(width: 100)
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
