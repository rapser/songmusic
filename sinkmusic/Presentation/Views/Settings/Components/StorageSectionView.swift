//
//  StorageSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Storage Section (Reusable Component)

struct StorageSectionView: View {
    let totalStorage: String
    let downloadedCount: Int
    let onDeleteAll: () -> Void

    var body: some View {
        Group {
            SettingsRowView(
                icon: "internaldrive.fill",
                iconColor: .gray,
                title: "Espacio usado",
                value: totalStorage
            )

            DeleteAllDownloadsButton(
                downloadedCount: downloadedCount,
                isEnabled: downloadedCount > 0,
                onDelete: onDeleteAll
            )
        }
    }
}

// MARK: - Delete All Downloads Button

private struct DeleteAllDownloadsButton: View {
    let downloadedCount: Int
    let isEnabled: Bool
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 12) {
                SettingsIconBadge(systemName: "trash.fill", color: .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Eliminar todas las descargas")
                        .foregroundColor(.red)

                    if downloadedCount > 0 {
                        Text("\(downloadedCount) canciones descargadas")
                            .font(.caption)
                            .foregroundColor(.textGray)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}
