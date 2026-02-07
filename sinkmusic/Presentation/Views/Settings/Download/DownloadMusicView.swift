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
    @Environment(DownloadViewModel.self) private var downloadViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var songForPlaylistSheet: SongUI?

    var pendingSongs: [SongUI] {
        libraryViewModel.songs.filter { !$0.isDownloaded }
    }

    var body: some View {
        @Bindable var download = downloadViewModel
        ZStack {
            Color.appDark.ignoresSafeArea()
            contentView
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(song: song)
        }
        .navigationTitle("Descargar música")
        .navigationBarTitleDisplayMode(.large)
        .alert("Límite de Descarga Alcanzado", isPresented: $download.showQuotaAlert) {
            Button("Entendido", role: .cancel) {
                downloadViewModel.dismissQuotaAlert()
            }
        } message: {
            if let timeFormatted = downloadViewModel.quotaResetTimeFormatted {
                Text("Has alcanzado el límite de descarga de Mega (5GB/día). Podrás continuar descargando \(timeFormatted).")
            } else {
                Text("Has alcanzado el límite de descarga de Mega (5GB/día). Por favor espera antes de continuar.")
            }
        }
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

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        playerVM: PreviewViewModels.playerVM(),
        settingsVM: PreviewViewModels.settingsVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { DownloadMusicView() }
}
