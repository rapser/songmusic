//
//  TopSongCard.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//


import SwiftUI

struct TopSongCard: View {
    let song: SongUI

    @Environment(ArtworkImageCache.self) private var artworkCache

    /// Carátula al tamaño de la tarjeta. Llega un instante después del thumbnail: la
    /// tarjeta mide 150×155 pt y el thumbnail que viaja en `SongUI` son 64 px, así que
    /// pintarlo tal cual se ampliaba siete veces. Ver `ArtworkImageCache`.
    @State private var sharpArtwork: UIImage?

    private static let size = CGSize(width: 150, height: 155)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
                .cornerRadius(8)

            // Title
            Text(song.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: Self.size.width, alignment: .leading)

            // Artist
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(.textGray)
                .lineLimit(1)
                .frame(width: Self.size.width, alignment: .leading)
        }
        .frame(width: Self.size.width)
        // Se pide por `song.id`: al reordenarse el ranking, cada tarjeta vuelve a pedir
        // la carátula de la canción que le toca ahora.
        .task(id: song.id) {
            sharpArtwork = await artworkCache.image(for: song.id)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        // El thumbnail mientras llega el nítido: así la tarjeta nunca sale vacía.
        if let image = sharpArtwork ?? song.artworkThumbnail.flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.size.width, height: Self.size.height)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: Self.size.width, height: Self.size.height)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                )
        }
    }
}
