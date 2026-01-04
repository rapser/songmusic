import SwiftUI

struct SettingsView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var showSignOutAlert = false
    @State private var showDeleteAllAlert = false

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeaderView()

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
                        isGoogleDriveConfigured: viewModel.hasCredentials()
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
                authManager.signOut()
            }
        } message: {
            Text("¿Estás seguro de que quieres cerrar sesión?")
        }
    }

    // MARK: - Helpers

    private func makeUserProfile() -> UserProfile? {
        guard let fullName = authManager.userFullName,
              let email = authManager.userEmail,
              let userID = authManager.userID else {
            return nil
        }
        return UserProfile(
            fullName: fullName,
            email: email,
            userID: userID
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

private struct HeaderView: View {
    var body: some View {
        Text("Configuración")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }
}

#Preview {
    PreviewWrapper {
        SettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
}
