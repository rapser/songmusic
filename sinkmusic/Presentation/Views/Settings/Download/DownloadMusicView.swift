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
    @Environment(\.dismiss) private var dismiss

    @State private var songForPlaylistSheet: SongEntity?

    var pendingSongs: [SongEntity] {
        libraryViewModel.songs.filter { !$0.isDownloaded }
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
                } else if libraryViewModel.songs.isEmpty && !libraryViewModel.isLoadingSongs {
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
                            Task {
                                await libraryViewModel.syncLibraryWithCatalog()
                            }
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
                        // Header con contador
                        HStack(spacing: 16) {
                            Text("\(pendingSongs.count) canciones por descargar")
                                .font(.subheadline)
                                .foregroundColor(.textGray)

                            Spacer()
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
                                            Task {
                                                await playerViewModel.play(
                                                    songID: song.id,
                                                    queue: pendingSongs
                                                )
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
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(song: song)
        }
        .navigationTitle("Descargar música")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        playerVM: PreviewViewModels.playerVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { DownloadMusicView() }
}
