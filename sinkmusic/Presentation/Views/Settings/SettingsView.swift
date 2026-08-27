//
//  SettingsView.swift
//  sinkmusic
//
//  Pantalla de Ajustes: una sola lista nativa agrupada por secciones, estilo
//  Spotify/Tidal — sin subpantallas propias para cada grupo de opciones.
//  Refactorizado para usar AuthViewModel (Clean Architecture)
//

import SwiftUI

struct SettingsView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var showSignOutAlert = false
    @State private var showDeleteAllAlert = false

    var body: some View {
        List {
            Section {
                SettingsHeaderView()
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)

                if let profile = makeUserProfile() {
                    UserProfileSectionView(profile: profile)
                }
            }

            if let profile = makeUserProfile() {
                Section {
                    AccountSectionView(profile: profile)
                } header: {
                    SectionHeaderView(title: "Cuenta")
                }
            }

            Section {
                DownloadsSectionView(
                    pendingCount: pendingSongsCount,
                    isGoogleDriveConfigured: viewModel.hasCredentials,
                    libraryViewModel: libraryViewModel,
                    settingsViewModel: viewModel
                )
            } header: {
                SectionHeaderView(title: "Descargas")
            }

            Section {
                StorageSectionView(
                    totalStorage: viewModel.storageInfo?.formattedTotalSize ?? "0 MB",
                    downloadedCount: viewModel.downloadStats?.totalDownloaded ?? 0,
                    onDeleteAll: {
                        showDeleteAllAlert = true
                    }
                )
            } header: {
                SectionHeaderView(title: "Almacenamiento")
            }

            Section {
                AboutSectionView(appVersion: viewModel.appInfo?.fullVersion ?? "1.0.0")
            } header: {
                SectionHeaderView(title: "Acerca de")
            }

            Section {
                SignOutButtonView {
                    showSignOutAlert = true
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appDark)
        .listRowBackground(Color.appDark)
        .listRowSeparatorTint(Color.white.opacity(0.08))
        .task {
            await viewModel.loadAllInfo()
        }
        .alert("Eliminar todas las descargas", isPresented: $showDeleteAllAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task {
                    await handleDeleteAllDownloads()
                }
            }
        } message: {
            Text("Se eliminarán \(viewModel.downloadStats?.totalDownloaded ?? 0) canciones descargadas. Esta acción no se puede deshacer.")
        }
        .alert("Cerrar sesión", isPresented: $showSignOutAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar sesión", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("¿Estás seguro de que quieres cerrar sesión?")
        }
    }

    // MARK: - Helpers

    private func makeUserProfile() -> UserProfileData? {
        // Solo requiere userID — Apple solo envía email/fullName en el primer login
        guard let userID = authViewModel.userID else { return nil }
        return UserProfileData(
            fullName: authViewModel.userFullName,
            email: authViewModel.userEmail,
            userID: userID,
            isAppleAccount: true
        )
    }

    private var pendingSongsCount: Int {
        // Canciones no descargadas
        libraryViewModel.songs.filter { !$0.isDownloaded }.count
    }

    private func handleDeleteAllDownloads() async {
        // Pausar reproducción si está activa
        if playerViewModel.isPlaying {
            await playerViewModel.pause()
        }

        // Eliminar todas las descargas
        await viewModel.deleteAllDownloads()

        // Recargar información
        await viewModel.loadAllInfo()
    }
}

#Preview {
    PreviewWrapper {
        NavigationStack {
            SettingsView()
                .environment(PreviewData.authVM())
        }
    }
}
