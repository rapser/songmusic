//
//  DownloadMusicView.swift
//  sinkmusic
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct DownloadMusicView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel

    var pendingSongs: [Song] {
        songs.filter { !$0.isDownloaded }
    }

    init() {
        // Configurar apariencia del NavigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.spotifyBlack)
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
            Color.spotifyBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                if pendingSongs.isEmpty {
                    // Estado vacío
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.spotifyGreen)

                        VStack(spacing: 8) {
                            Text("Todo descargado")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("Todas las canciones están descargadas")
                                .font(.system(size: 14))
                                .foregroundColor(.spotifyLightGray)
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
                                    .foregroundColor(.spotifyLightGray)

                                if songListViewModel.isDownloadingAll {
                                    let downloadingCount = songListViewModel.downloadProgress.count
                                    Text("Descargando \(downloadingCount) de \(pendingSongs.count)...")
                                        .font(.caption)
                                        .foregroundColor(.spotifyGreen)
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
                                    .foregroundColor(.spotifyBlack)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.spotifyGreen)
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
    NavigationStack {
        DownloadMusicView()
            .modelContainer(PreviewContainer.shared.container)
            .environmentObject(PreviewViewModels.playerVM())
            .environmentObject(PreviewViewModels.songListVM())
    }
}
