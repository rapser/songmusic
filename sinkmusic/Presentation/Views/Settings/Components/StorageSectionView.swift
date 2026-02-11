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
        VStack(spacing: 0) {
            // Storage Used Row
            SettingsRowView(
                icon: "internaldrive.fill",
                title: "Espacio usado",
                value: totalStorage
            )

            // Delete All Downloads Button
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
            HStack {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Eliminar todas las descargas")
                        .font(.body)
                        .foregroundColor(.white)

                    if downloadedCount > 0 {
                        Text("\(downloadedCount) canciones descargadas")
                            .font(.caption)
                            .foregroundColor(.textGray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appGray)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}
