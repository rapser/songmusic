//
//  CreatePlaylistView.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//

import SwiftUI
import PhotosUI

@MainActor
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel

    var songToAdd: SongUI? = nil

    @State private var playlistName = ""
    @State private var playlistDescription = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var cachedCoverImage: UIImage?
    /// El `PHPicker` inicializa PhotoKit al aparecer y eso reconfigura la `AVAudioSession`
    /// compartida (sample rate / IO buffer / ruta) por debajo del engine que está sonando →
    /// crujido. Con el modificador `.photosPicker(isPresented:)` solo se monta cuando el
    /// usuario toca el recuadro, no al abrir el modal.
    @State private var showPhotoPicker = false
    /// Índice para uno de los 10 colores del placeholder (fondo con icono de música).
    @State private var placeholderColorIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 24) {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            CoverImagePlaceholder(
                                cachedImage: cachedCoverImage,
                                isLoading: coverImageData != nil,
                                gradient: PlaylistPlaceholderColors.gradient(at: placeholderColorIndex)
                            )
                        }
                        .buttonStyle(.plain)

                        // Text Fields
                        VStack(spacing: 16) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nombre")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)

                                TextField("Mi playlist", text: $playlistName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.appGray)
                                    .cornerRadius(8)
                                    .autocorrectionDisabled()
                            }

                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Descripción (opcional)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)

                                TextField("Agrega una descripción", text: $playlistDescription, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.appGray)
                                    .cornerRadius(8)
                                    .lineLimit(3...6)
                                    .autocorrectionDisabled()
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()
                    }
                    .padding(.top, 30)
                }
            }
            .navigationTitle("Nueva playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Crear") {
                        createPlaylist()
                    }
                    .foregroundColor(playlistName.isEmpty ? .gray : .appPurple)
                    .disabled(playlistName.isEmpty)
                }
            }
            .onAppear {
                placeholderColorIndex = Int.random(in: 0..<15)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedImage, matching: .images)
            .onChange(of: selectedImage) { _, newValue in
                Task.detached(priority: .userInitiated) {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        let image = UIImage(data: data)
                        await MainActor.run {
                            coverImageData = data
                            cachedCoverImage = image
                        }
                    }
                }
            }
        }
    }

    private func createPlaylist() {
        Task {
            let newPlaylistID = try? await viewModel.createPlaylist(
                name: playlistName,
                description: playlistDescription.isEmpty ? nil : playlistDescription,
                coverImageData: coverImageData,
                placeholderColorIndex: placeholderColorIndex
            )

            // Si se creó la playlist y hay una canción para agregar, agregarla
            if let playlistID = newPlaylistID, let song = songToAdd {
                await viewModel.addSongToPlaylist(songID: song.id, playlistID: playlistID)
            }

            dismiss()
        }
    }
}

/// Muestra la imagen en caché, placeholder de carga o botón "Elegir foto". Solo recibe valores (no bindings) para que el PhotosPicker content no toque MainActor.
/// Si se pasa gradient, el fondo sin foto usa uno de los 10 colores de playlist; si no, gris.
private struct CoverImagePlaceholder: View {
    let cachedImage: UIImage?
    let isLoading: Bool
    var gradient: (Color, Color)? = nil

    var body: some View {
        ZStack {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipped()
                    .cornerRadius(8)
            } else if isLoading {
                Color.appGray
                    .frame(width: 180, height: 180)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            } else {
                Group {
                    if let (c1, c2) = gradient {
                        LinearGradient(
                            gradient: Gradient(colors: [c1, c2]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.appGray
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Elegir foto")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                )
            }
        }
    }
}

#Preview {
    PreviewWrapper(
        playlistVM: PreviewViewModels.playlistVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) {
        CreatePlaylistView()
    }
}
