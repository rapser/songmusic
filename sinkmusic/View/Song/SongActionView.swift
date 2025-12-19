//
//  SongActionView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Componente optimizado para las acciones de la canción (descarga, menú, progreso)
struct SongActionView: View {
    let song: Song
    let downloadProgress: Double?
    @Binding var showMenu: Bool
    let onDownload: () -> Void

    var body: some View {
        Group {
            if let progress = downloadProgress {
                // Siempre mostrar la barra de progreso (0% a 100%)
                DownloadProgressView(progress: progress)
            } else if song.isDownloaded {
                MenuButton(showMenu: $showMenu)
            } else {
                DownloadButton(action: onDownload)
            }
        }
    }
}
