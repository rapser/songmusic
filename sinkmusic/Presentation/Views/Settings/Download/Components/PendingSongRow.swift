//
//  PendingSongRow.swift
//  sinkmusic
//
//  Fila para la lista de canciones pendientes de descarga.
//  A diferencia de SongRow, aquí no hay reproducción: la canción todavía no está
//  descargada, así que no hay icono de play ni tap-para-reproducir — solo la
//  información de la canción y la acción de descarga (o su progreso).
//

import SwiftUI

struct PendingSongRow: View {
    let song: SongUI

    @Environment(DownloadViewModel.self) private var downloadViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.textGray)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let progress = downloadViewModel.downloadProgress[song.id] {
                DownloadProgressView(progress: progress)
            } else {
                DownloadButton {
                    Task {
                        await downloadViewModel.download(songID: song.id)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
    }
}
