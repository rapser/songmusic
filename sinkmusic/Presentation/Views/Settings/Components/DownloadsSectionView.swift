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
        Group {
            NavigationLink(destination: DownloadMusicView()) {
                HStack(spacing: 12) {
                    SettingsIconBadge(systemName: "arrow.down.circle.fill", color: .appPurple)

                    Text("Descargar música")
                        .foregroundColor(.white)

                    Spacer()

                    if pendingCount > 0 {
                        PendingBadgeView(count: pendingCount)
                    }
                }
                .padding(.vertical, 4)
            }

            NavigationLink(destination: CloudStorageConfigView()) {
                HStack(spacing: 12) {
                    SettingsIconBadge(systemName: "cloud.fill", color: .blue)

                    Text("Configurar almacenamiento")
                        .foregroundColor(.white)

                    Spacer()

                    ProviderBadgeView(provider: settingsViewModel.selectedProvider,
                                      isConfigured: settingsViewModel.hasCurrentProviderCredentials)
                }
                .padding(.vertical, 4)
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
