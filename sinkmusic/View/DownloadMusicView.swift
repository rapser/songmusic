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
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header con contador
                            HStack {
                                Text("\(pendingSongs.count) canciones por descargar")
                                    .font(.subheadline)
                                    .foregroundColor(.spotifyLightGray)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            // Lista
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
                            .padding(.bottom, 100)
                        }
                        .padding(.horizontal, 16)
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
