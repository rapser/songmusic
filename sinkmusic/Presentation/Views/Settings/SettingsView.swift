//
//  SettingsView.swift
//  sinkmusic
//
//  Settings screen - Refactored to use AuthViewModel (Clean Architecture)
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
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsHeaderView()

                    // User Profile Section
                    if let profile = makeUserProfile() {
                        UserProfileSectionView(profile: profile)
                    }

                    SectionHeaderView(title: "Cuenta")
                    if let profile = makeUserProfile() {
                        AccountSectionView(profile: profile)
                    }

                    SectionHeaderView(title: "Descargas")
                    DownloadsSectionView(
                        pendingCount: pendingSongsCount,
                        isGoogleDriveConfigured: viewModel.hasCredentials,
                        libraryViewModel: libraryViewModel,
                        settingsViewModel: viewModel
                    )

                    SectionHeaderView(title: "Almacenamiento")
                    StorageSectionView(
                        totalStorage: viewModel.storageInfo?.formattedTotalSize ?? "0 MB",
                        downloadedCount: viewModel.downloadStats?.totalDownloaded ?? 0,
                        onDeleteAll: {
                            showDeleteAllAlert = true
                        }
                    )

                    SectionHeaderView(title: "Acerca de")
                    AboutSectionView(appVersion: viewModel.appInfo?.fullVersion ?? "1.0.0")

                    SignOutButtonView {
                        showSignOutAlert = true
                    }
                }
            }
        }
        .task {
            // Cargar información al aparecer
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
        SettingsView()
            .environment(PreviewData.authVM())
    }
}
