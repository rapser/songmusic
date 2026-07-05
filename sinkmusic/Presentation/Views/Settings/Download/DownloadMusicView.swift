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
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(DownloadViewModel.self) private var downloadViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showErrorAlert = false

    var pendingSongs: [SongUI] {
        libraryViewModel.songs.filter { !$0.isDownloaded }
    }

    var body: some View {
        @Bindable var download = downloadViewModel
        ZStack {
            Color.appDark.ignoresSafeArea()
            contentView
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
        .task {
            if downloadViewModel.isMegaProvider {
                await libraryViewModel.syncLibraryWithCatalog()
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
            AllDownloadedView(onSync: {
                Task {
                    await libraryViewModel.syncLibraryWithCatalog()
                }
            }, showsSyncAction: downloadViewModel.isMegaProvider)
        } else if libraryViewModel.isLoadingSongs {
            LoadingStateView()
        } else {
            VStack(spacing: 0) {
                if downloadViewModel.isMegaProvider {
                    bulkDownloadSection
                }
                PendingSongsListView(
                    pendingSongs: pendingSongs,
                    onRefresh: {
                        await libraryViewModel.syncLibraryWithCatalog()
                    }
                )
            }
        }
    }

    /// Botón "Descargar todo" solo para Mega; deshabilitado e informa si se alcanzó el límite
    @ViewBuilder
    private var bulkDownloadSection: some View {
        let quotaExceeded = downloadViewModel.isMegaQuotaExceeded
        VStack(spacing: 8) {
            Button {
                guard !quotaExceeded else {
                    downloadViewModel.showQuotaAlert = true
                    return
                }
                Task {
                    await downloadViewModel.downloadMultiple(songIDs: pendingSongs.map(\.id))
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Descargar todo")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(quotaExceeded ? .textGray : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(quotaExceeded ? Color.appGray : Color.appPurple)
                .cornerRadius(10)
            }
            .disabled(quotaExceeded)
            .buttonStyle(.plain)

            if quotaExceeded {
                Text("Límite de Mega alcanzado (5 GB/día). \(downloadViewModel.quotaResetTimeFormatted ?? "Espera para volver a descargar.")")
                    .font(.caption)
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appGray.opacity(0.5))
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
