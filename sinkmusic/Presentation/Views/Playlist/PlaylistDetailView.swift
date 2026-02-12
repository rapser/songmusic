//
//  PlaylistDetailView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//  Refactored to Clean Architecture - No SwiftData in View
//

import SwiftUI

struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel

    let playlist: PlaylistUI
    @State private var showEditSheet = false
    @State private var showEditPlaylistSheet = false
    @State private var showDeleteAlert = false
    @State private var showAddSongsSheet = false
    @State private var songForPlaylistSheet: SongUI?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        baseView
            .task {
                await viewModel.loadSongsInPlaylist(playlist.id)
            }
            .sheet(isPresented: $showAddSongsSheet) {
                AddSongsToPlaylistView(playlist: playlist)
            }
            .sheet(item: $songForPlaylistSheet) { song in
                AddToPlaylistView(song: song)
            }
            .sheet(isPresented: $showEditPlaylistSheet) {
                EditPlaylistView(playlist: playlist)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    editToolbarButton
                }
            }
            .confirmationDialog("Opciones de playlist", isPresented: $showEditSheet) {
                editDialogButtons
            }
            .alert("¿Eliminar playlist?", isPresented: $showDeleteAlert) {
                deleteAlertButtons
            } message: {
                Text("Esta acción no se puede deshacer")
            }
    }

    private var baseView: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)
            mainContentView
        }
    }

    @ViewBuilder
    private var editToolbarButton: some View {
        if !viewModel.songsInPlaylist.isEmpty {
            Button(editMode == .active ? "Listo" : "Editar") {
                withAnimation {
                    editMode = editMode == .active ? .inactive : .active
                }
            }
            .foregroundColor(.appPurple)
        }
    }

    @ViewBuilder
    private var editDialogButtons: some View {
        Button("Editar información") {
            showEditPlaylistSheet = true
        }
        Button("Eliminar playlist", role: .destructive) {
            showDeleteAlert = true
        }
        Button("Cancelar", role: .cancel) {}
    }

    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancelar", role: .cancel) {}
        Button("Eliminar", role: .destructive) {
            Task {
                await viewModel.deletePlaylist(playlist.id)
                dismiss()
            }
        }
    }

    // MARK: - View Components

    private var mainContentView: some View {
        // List es necesario para que .onMove (drag & drop) funcione.
        // LazyVStack + ScrollView acepta .onMove sin error pero nunca lo activa.
        List {
            // Header y botones como sección sin separadores
            Section {
                headerView
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    // frame(maxWidth: .infinity) es necesario para que el VStack
                    // interno centre su contenido horizontalmente en el List.
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appDark)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                actionButtonsView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appDark)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            // Sección de canciones con drag & drop
            songsListView

            // Espaciado inferior para el mini-player
            Section {
                Color.clear.frame(height: 80)
                    .listRowBackground(Color.appDark)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appDark)
        // El handle de drag nativo usa el tint del List como color.
        // Se fuerza blanco para máxima visibilidad en fondos oscuros.
        .tint(Color.white)
        // Propagar editMode al List para que .onMove muestre el handle de arrastre
        .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private var songsListView: some View {
        if viewModel.songsInPlaylist.isEmpty {
            Section {
                EmptyPlaylistSongsView(onAddSongs: { showAddSongsSheet = true })
                    .listRowBackground(Color.appDark)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
        } else {
            songsList
        }
    }

    private var songsList: some View {
        Section {
            ForEach(viewModel.songsInPlaylist) { song in
                songRowView(for: song)
                    .listRowBackground(Color.appDark)
                    .listRowSeparator(.hidden)
                    // SongRow ya tiene .padding(.horizontal, 20) propio.
                    // Eliminamos los insets del sistema para no duplicar el padding izquierdo.
                    // El handle de drag del List ocupa su espacio natural a la derecha.
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onMove { source, destination in
                Task {
                    await viewModel.reorderSongs(in: playlist.id, fromOffsets: source, toOffset: destination)
                }
            }
        }
    }

    private func songRowView(for song: SongUI) -> some View {
        SongRow(
            song: song,
            songQueue: viewModel.songsInPlaylist,
            isCurrentlyPlaying: playerViewModel.currentlyPlayingID == song.id,
            isPlaying: playerViewModel.isPlaying,
            isReordering: editMode == .active,
            onPlay: {
                Task {
                    await playerViewModel.play(songID: song.id, queue: viewModel.songsInPlaylist)
                }
            },
            onPause: {
                Task {
                    await playerViewModel.pause()
                }
            },
            showAddToPlaylistForSong: $songForPlaylistSheet,
            playlist: playlist,
            onRemoveFromPlaylist: {
                Task {
                    await viewModel.removeSongFromPlaylist(songID: song.id, playlistID: playlist.id)
                }
            }
        )
    }

    private var headerView: some View {
        VStack(alignment: .center, spacing: 16) {
            // Cover Image
            coverImageView
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

            // Playlist Info
            playlistInfoView
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var coverImageView: some View {
        ZStack {
            if let coverData = playlist.coverImageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipped()
            } else {
                defaultCoverView
            }
        }
    }

    private var defaultCoverView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.6, brightness: 0.5),
                Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.7, brightness: 0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 200, height: 200)
        .overlay(
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
        )
    }

    private var playlistInfoView: some View {
        VStack(spacing: 8) {
            Text(playlist.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if !playlist.description.isEmpty {
                Text(playlist.description)
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Text("\(playlist.songCount) canciones • \(playlist.formattedDuration)")
                .font(.system(size: 13))
                .foregroundColor(.textGray)
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            // Play All Button
            if !playlist.songs.isEmpty {
                Button(action: { playAll() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("Reproducir")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appPurple)
                    .cornerRadius(24)
                    .fixedSize()
                }
            }

            // Add Songs Button
            Button(action: { showAddSongsSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                    Text("Agregar")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)
                .fixedSize()
            }

            // Edit Button
            Button(action: { showEditSheet = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textGray)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
            }
            Spacer(minLength: 0)
        }
    }

    private func playAll() {
        guard !viewModel.songsInPlaylist.isEmpty else { return }
        Task {
            await playerViewModel.play(songID: viewModel.songsInPlaylist[0].id, queue: viewModel.songsInPlaylist)
        }
    }
}

#Preview {
    NavigationStack {
        PreviewWrapper(
            playerVM: PreviewViewModels.playerVM(songID: UUID()),
            modelContainer: PreviewContainer.shared.container
        ) {
            PlaylistDetailView(playlist: PlaylistMapper.toUI(PlaylistMapper.toDomainWithSongs(PreviewPlaylists.samplePlaylist())))
        }
    }
}

