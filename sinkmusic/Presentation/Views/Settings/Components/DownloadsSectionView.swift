//
//  DownloadsSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Downloads Section (Reusable Component)

struct DownloadsSectionView: View {
    let pendingCount: Int
    let isGoogleDriveConfigured: Bool
    let libraryViewModel: LibraryViewModel
    let settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Download Music Button
            NavigationLink(destination: DownloadMusicView()) {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.textGray)
                        .frame(width: 24)

                    Text("Descargar música")
                        .foregroundColor(.white)

                    Spacer()

                    if pendingCount > 0 {
                        PendingBadgeView(count: pendingCount)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.textGray)
                        .font(.caption)
                }
                .padding(16)
                .background(Color.appGray)
            }

            // Cloud Storage Config Button
            NavigationLink(destination: CloudStorageConfigView()) {
                HStack(spacing: 16) {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.textGray)
                        .frame(width: 24)

                    Text("Configurar Almacenamiento")
                        .foregroundColor(.white)

                    Spacer()

                    // Mostrar badge del proveedor seleccionado
                    ProviderBadgeView(provider: settingsViewModel.selectedProvider,
                                      isConfigured: settingsViewModel.hasCurrentProviderCredentials)

                    Image(systemName: "chevron.right")
                        .foregroundColor(.textGray)
                        .font(.caption)
                }
                .padding(16)
                .background(Color.appGray)
            }
        }
    }
}

// MARK: - Pending Badge

private struct PendingBadgeView: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .foregroundColor(.white)
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appPurple)
            .cornerRadius(12)
    }
}

// MARK: - Provider Badge

private struct ProviderBadgeView: View {
    let provider: CloudStorageProvider
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider == .googleDrive ? "g.circle.fill" : "m.circle.fill")
                .font(.caption)

            if isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appPurple)
            }
        }
        .foregroundColor(isConfigured ? .appPurple : .textGray)
    }
}
