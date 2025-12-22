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
    
    @State private var songForPlaylistSheet: Song?

    var pendingSongs: [Song] {
        songs.filter { !$0.isDownloaded }
    }

    var body: some View {
        let playlistViewModel = PlaylistViewModel(modelContext: modelContext)
        
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
                } else if songs.isEmpty && !libraryViewModel.isLoadingSongs {
                    // No hay canciones en la biblioteca
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

                        Button(action: {
                            libraryViewModel.syncLibraryWithCatalog(modelContext: modelContext)
                        }) {
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
                } else if pendingSongs.isEmpty && !libraryViewModel.isLoadingSongs {
                    // Estado vacío - todo descargado
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
                            LazyVStack(spacing: 0) {
                                ForEach(pendingSongs) { song in
                                    SongRow(
                                        song: song,
                                        songQueue: pendingSongs,
                                        isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
                                        isPlaying: playerViewModel.isPlaying,
                                        onPlay: {
                                            if let url = song.localURL {
                                                playerViewModel.play(song: song, from: url, in: pendingSongs)
                                            }
                                        },
                                        onPause: {
                                            playerViewModel.pause()
                                        },
                                        showAddToPlaylistForSong: $songForPlaylistSheet
                                    )
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(viewModel: playlistViewModel, song: song)
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
