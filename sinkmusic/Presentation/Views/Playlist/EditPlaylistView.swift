//
//  EditPlaylistView.swift
//  sinkmusic
//
//  Vista para editar información de una playlist existente
//

import SwiftUI
import PhotosUI

struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel

    let playlist: PlaylistUIModel

    @State private var playlistName: String
    @State private var playlistDescription: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var cachedCoverImage: UIImage?

    init(playlist: PlaylistUIModel) {
        self.playlist = playlist
        _playlistName = State(initialValue: playlist.name)
        _playlistDescription = State(initialValue: playlist.description)
        _coverImageData = State(initialValue: playlist.coverImageData)
        if let imageData = playlist.coverImageData {
            _cachedCoverImage = State(initialValue: UIImage(data: imageData))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 24) {
                        // Cover Image Picker
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            ZStack {
                                if let cachedImage = cachedCoverImage {
                                    Image(uiImage: cachedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 180, height: 180)
                                        .clipped()
                                        .cornerRadius(8)
                                } else if coverImageData != nil {
                                    // Mostrar placeholder mientras carga
                                    Color.appGray
                                        .frame(width: 180, height: 180)
                                        .cornerRadius(8)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.appGray)
                                        .frame(width: 180, height: 180)
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
                        .onChange(of: selectedImage) { _, newValue in
                            Task.detached(priority: .userInitiated) {
                                // Cargar la imagen en background para no bloquear el UI ni el audio
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    // Decodificar la imagen en background
                                    let image = UIImage(data: data)
                                    await MainActor.run {
                                        coverImageData = data
                                        cachedCoverImage = image
                                    }
                                }
                            }
                        }

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
            .navigationTitle("Editar playlist")
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
                    Button("Guardar") {
                        updatePlaylist()
                    }
                    .foregroundColor(playlistName.isEmpty ? .gray : .appPurple)
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }

    private func updatePlaylist() {
        Task {
            await viewModel.updatePlaylist(
                id: playlist.id,
                name: playlistName,
                description: playlistDescription.isEmpty ? nil : playlistDescription,
                coverImageData: coverImageData
            )
            dismiss()
        }
    }
}
