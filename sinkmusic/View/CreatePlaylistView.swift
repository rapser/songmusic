//
//  CreatePlaylistView.swift
//  sinkmusic
//
//  Created by Claude Code
//

import SwiftUI
import PhotosUI

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PlaylistViewModel

    @State private var playlistName = ""
    @State private var playlistDescription = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImageData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spotifyBlack.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 24) {
                        // Cover Image Picker
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            ZStack {
                                if let coverImageData = coverImageData,
                                   let uiImage = UIImage(data: coverImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 180, height: 180)
                                        .clipped()
                                        .cornerRadius(8)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.spotifyGray)
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
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    coverImageData = data
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
                                    .background(Color.spotifyGray)
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
                                    .background(Color.spotifyGray)
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
                    .foregroundColor(playlistName.isEmpty ? .gray : .spotifyGreen)
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }

    private func createPlaylist() {
        viewModel.createPlaylist(
            name: playlistName,
            description: playlistDescription,
            coverImageData: coverImageData
        )
        dismiss()
    }
}

#Preview {
    CreatePlaylistView(viewModel: PlaylistViewModel(modelContext: PreviewContainer.shared.mainContext))
}
