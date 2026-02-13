//
//  SongActionView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//

import SwiftUI

/// Acciones de la canción: descarga, botón de 3 puntos (abre confirmationDialog) o progreso.
/// Usamos confirmationDialog en lugar de Menu para evitar advertencias de consola en List.
struct SongActionView: View {
    let isDownloaded: Bool
    let downloadProgress: Double?
    @Binding var showMenu: Bool
    let onDownload: () -> Void

    var body: some View {
        Group {
            if let progress = downloadProgress {
                DownloadProgressView(progress: progress)
            } else if isDownloaded {
                Button(action: { showMenu = true }) {
                    ThreeDotsLabel()
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
            } else {
                DownloadButton(action: onDownload)
            }
        }
    }
}
