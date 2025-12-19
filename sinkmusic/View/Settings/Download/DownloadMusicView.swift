//
//  DownloadMusicView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI
import SwiftData

struct DownloadMusicView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    var pendingSongs: [Song] {
        songs.filter { !$0.isDownloaded }
    }

    init() {
        // Configurar apariencia del NavigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appDark)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        // Botón de back en blanco
        appearance.setBackIndicatorImage(
            UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal),
            transitionMaskImage: UIImage(systemName: "chevron.left")
        )

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some View {
        ZStack {
            Color.appDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Mostrar error si existe
                if let errorMessage = libraryViewModel.syncErrorMessage {
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
                } else if pendingSongs.isEmpty && !libraryViewModel.isLoadingSongs {
                    // Estado vacío
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
                } else if libraryViewModel.isLoadingSongs {
                    // Estado de carga
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
                } else {
                    // Lista de canciones pendientes
                    VStack(spacing: 0) {
                        // Header con contador y botón de descargar todas
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(pendingSongs.count) canciones por descargar")
                                    .font(.subheadline)
                                    .foregroundColor(.textGray)

                                if songListViewModel.isDownloadingAll {
                                    let downloadingCount = songListViewModel.downloadProgress.count
                                    Text("Descargando \(downloadingCount) de \(pendingSongs.count)...")
                                        .font(.caption)
                                        .foregroundColor(.appPurple)
                                }
                            }

                            Spacer()

                            if songListViewModel.isDownloadingAll {
                                Button(action: {
                                    songListViewModel.cancelDownloadAll()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 12))
                                        Text("Detener")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .cornerRadius(20)
                                }
                            } else {
                                Button(action: {
                                    songListViewModel.downloadAll(songs: pendingSongs, modelContext: modelContext)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Descargar todas")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.appDark)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.appPurple)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Lista
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(pendingSongs) { song in
                                    SongRow(song: song)

                                    if song.id != pendingSongs.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .navigationTitle("Descargar música")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        songListVM: PreviewViewModels.songListVM(),
        playerVM: PreviewViewModels.playerVM(),
        modelContainer: PreviewContainer.shared.container
    ) {
        NavigationStack {
            DownloadMusicView()
        }
    }
}
