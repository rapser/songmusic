//
//  EditPlaylistView.swift
//  sinkmusic
//
//  Vista para editar información de una playlist existente
//

import SwiftUI
import PhotosUI

@MainActor
struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel

    let playlist: PlaylistUI

    @State private var playlistName: String
    @State private var playlistDescription: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var cachedCoverImage: UIImage?
    @State private var showCoverPicker = false
    /// Índice del color del placeholder (0 a N-1). nil = color por defecto (por id).
    @State private var selectedPlaceholderColorIndex: Int?

    init(playlist: PlaylistUI) {
        self.playlist = playlist
        _playlistName = State(initialValue: playlist.name)
        _playlistDescription = State(initialValue: playlist.description)
        _coverImageData = State(initialValue: playlist.coverImageData)
        _selectedPlaceholderColorIndex = State(initialValue: playlist.placeholderColorIndex)
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
                        if showCoverPicker {
                            CoverImagePickerContent(
                                selectedImage: $selectedImage,
                                coverImageData: $coverImageData,
                                cachedCoverImage: $cachedCoverImage,
                                placeholderGradient: placeholderGradient
                            )
                        } else {
                            CoverImagePlaceholder(
                                cachedImage: cachedCoverImage,
                                isLoading: coverImageData != nil,
                                gradient: placeholderGradient
                            )
                        }

                        // Color del placeholder (solo cuando no hay foto de portada)
                        if coverImageData == nil && cachedCoverImage == nil {
                            PlaceholderColorPickerSection(selectedIndex: $selectedPlaceholderColorIndex)
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
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(280))
                    showCoverPicker = true
                }
            }
        }
    }

    private var placeholderGradient: (Color, Color)? {
        let idx = selectedPlaceholderColorIndex ?? playlist.placeholderColorIndex
        guard let idx else { return nil }
        return PlaylistPlaceholderColors.gradient(at: idx)
    }

    private func updatePlaylist() {
        Task {
            await viewModel.updatePlaylist(
                id: playlist.id,
                name: playlistName,
                description: playlistDescription.isEmpty ? nil : playlistDescription,
                coverImageData: coverImageData,
                placeholderColorIndex: selectedPlaceholderColorIndex
            )
            dismiss()
        }
    }
}

// MARK: - Cover image picker (subvista @MainActor; lee estado en body y pasa snapshot al closure)
@MainActor
private struct CoverImagePickerContent: View {
    @Binding var selectedImage: PhotosPickerItem?
    @Binding var coverImageData: Data?
    @Binding var cachedCoverImage: UIImage?
    var placeholderGradient: (Color, Color)?

    var body: some View {
        let cached = cachedCoverImage
        let isLoading = coverImageData != nil
        PhotosPicker(selection: $selectedImage, matching: .images) {
            CoverImagePlaceholder(cachedImage: cached, isLoading: isLoading, gradient: placeholderGradient)
        }
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

/// Muestra la imagen en caché, placeholder de carga o botón "Elegir foto". Si hay gradient, el fondo sin foto usa ese color.
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

/// Selector de color del placeholder en carrusel horizontal (ocupa poco espacio).
private struct PlaceholderColorPickerSection: View {
    @Binding var selectedIndex: Int?

    private let circleSize: CGFloat = 44
    private let spacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color del placeholder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    // Por defecto (color automático por id)
                    Button {
                        selectedIndex = nil
                    } label: {
                        ZStack {
                            Color.appGray
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: circleSize, height: circleSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(selectedIndex == nil ? Color.white : Color.clear, lineWidth: 3)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(0..<PlaylistPlaceholderColors.numberOfColors, id: \.self) { index in
                        let (c1, c2) = PlaylistPlaceholderColors.gradient(at: index)
                        let isSelected = selectedIndex == index
                        Button {
                            selectedIndex = index
                        } label: {
                            LinearGradient(
                                gradient: Gradient(colors: [c1, c2]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: circleSize, height: circleSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: circleSize + 4)
        }
        .padding(.horizontal, 20)
    }
}
