//
//  PlaylistsCarouselView.swift
//  sinkmusic
//
//  Sección "Playlists más escuchadas" en Inicio — scroll horizontal, máximo 10.
//

import SwiftUI

struct PlaylistsCarouselView: View {
    let playlists: [PlaylistUI]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playlists más escuchadas")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            if playlists.isEmpty {
                EmptyPlaylistsCarouselView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                PlaylistCarouselCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

/// Tarjeta compacta para el carrusel horizontal (portada + nombre).
/// Mismo ancho para portada y título, alineados a la izquierda como en Canciones más escuchadas.
private struct PlaylistCarouselCard: View {
    let playlist: PlaylistUI
    @State private var cachedImage: UIImage?

    private let size: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                } else if playlist.coverImageData != nil {
                    Color.appGray
                        .frame(width: size, height: size)
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.7))
                } else {
                    let (c1, c2) = PlaylistPlaceholderColors.gradient(for: playlist)
                    LinearGradient(
                        gradient: Gradient(colors: [c1, c2]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(8)

            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: size, alignment: .leading)
        }
        .frame(width: size, alignment: .leading)
        .task(id: playlist.id) {
            if let coverData = playlist.coverImageData, cachedImage == nil {
                await Task.detached(priority: .userInitiated) {
                    let image = UIImage(data: coverData)
                    await MainActor.run { cachedImage = image }
                }.value
            }
        }
    }
}

/// Placeholder cuando no hay playlists en el carrusel.
private struct EmptyPlaylistsCarouselView: View {
    var body: some View {
        Text("Crea playlists y reprodúcelas para verlas aquí")
            .font(.system(size: 14))
            .foregroundColor(.textGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        Color.appDark.ignoresSafeArea()
        PlaylistsCarouselView(playlists: [])
    }
}
