//
//  PendingSongsListView.swift
//  sinkmusic
//
//  Lista de canciones pendientes de descarga (paginada para mejor rendimiento)
//

import SwiftUI

private let pageSize = 20

struct PendingSongsListView: View {
    let pendingSongs: [SongUI]
    let onRefresh: () async -> Void

    @State private var displayedCount = pageSize

    /// Solo las canciones visibles en la ventana actual (paginación)
    private var displayedSongs: [SongUI] {
        Array(pendingSongs.prefix(displayedCount))
    }

    private var hasMore: Bool {
        displayedCount < pendingSongs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            songsList
        }
        .onChange(of: pendingSongs.count) { _, newCount in
            // Si la lista se redujo (ej. se descargó una canción), ajustar displayedCount
            if displayedCount > newCount {
                displayedCount = min(displayedCount, max(pageSize, newCount))
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Text("\(pendingSongs.count) canciones por descargar")
                .font(.subheadline)
                .foregroundColor(.textGray)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedSongs) { song in
                    PendingSongRow(song: song)
                }

                if hasMore {
                    loadMoreButton
                }
            }
            .padding(.bottom, 16)
        }
        .refreshable {
            await onRefresh()
        }
    }

    private var loadMoreButton: some View {
        Button {
            displayedCount = min(displayedCount + pageSize, pendingSongs.count)
        } label: {
            HStack {
                Text("Cargar más (\(displayedSongs.count) de \(pendingSongs.count))")
                    .font(.subheadline)
                    .foregroundColor(.appPurple)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.appPurple)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
