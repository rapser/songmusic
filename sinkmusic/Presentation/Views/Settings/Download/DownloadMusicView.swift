//
//  DownloadMusicView.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  No SwiftData dependency in View
//

import SwiftUI

struct DownloadMusicView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var songForPlaylistSheet: SongUIModel?

    var pendingSongs: [SongUIModel] {
        libraryViewModel.songs.filter { !$0.isDownloaded }
    }

    var body: some View {
        ZStack {
            Color.appDark.ignoresSafeArea()
            contentView
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(song: song)
        }
        .navigationTitle("Descargar música")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var contentView: some View {
        if let errorMessage = libraryViewModel.syncErrorMessage {
            ErrorStateView(errorMessage: errorMessage)
        } else if libraryViewModel.songs.isEmpty && !libraryViewModel.isLoadingSongs {
            EmptyLibraryView(onSync: {
                Task {
                    await libraryViewModel.syncLibraryWithCatalog()
                }
            })
        } else if pendingSongs.isEmpty && !libraryViewModel.isLoadingSongs {
            AllDownloadedView()
        } else if libraryViewModel.isLoadingSongs {
            LoadingStateView()
        } else {
            PendingSongsListView(
                pendingSongs: pendingSongs,
                playerViewModel: playerViewModel,
                songForPlaylistSheet: $songForPlaylistSheet
            )
        }
    }
}

// MARK: - Subviews

private struct ErrorStateView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Error de sincronización")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            NavigationLink(destination: GoogleDriveConfigView()) {
                Text("Revisar Configuración")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }
            .padding(.top, 10)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

private struct EmptyLibraryView: View {
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.appPurple)

            VStack(spacing: 8) {
                Text("Biblioteca vacía")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Sincroniza tus canciones desde Google Drive")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSync) {
                Text("Sincronizar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

private struct AllDownloadedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.appPurple)

            VStack(spacing: 8) {
                Text("Todo descargado")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Todas las canciones están descargadas")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

private struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appPurple))
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Sincronizando...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Obteniendo canciones de Google Drive")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

private struct PendingSongsListView: View {
    let pendingSongs: [SongUIModel]
    let playerViewModel: PlayerViewModel
    @Binding var songForPlaylistSheet: SongUIModel?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            songsList
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Text("\(pendingSongs.count) canciones por descargar")
                .font(.subheadline)
                .foregroundColor(.textGray)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(pendingSongs) { song in
                    songRow(for: song)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func songRow(for song: SongUIModel) -> some View {
        SongRow(
            song: song,
            songQueue: pendingSongs,
            isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
            isPlaying: playerViewModel.isPlaying,
            onPlay: {
                Task {
                    // TODO: PlayerViewModel.play needs updating to accept [SongUIModel]
                    // await playerViewModel.play(songID: song.id, queue: pendingSongs)
                }
            },
            onPause: {
                Task {
                    await playerViewModel.pause()
                }
            },
            showAddToPlaylistForSong: $songForPlaylistSheet
        )
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        playerVM: PreviewViewModels.playerVM(),
        settingsVM: PreviewViewModels.settingsVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { DownloadMusicView() }
}
