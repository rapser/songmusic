import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var viewModel = RefactoredSettingsViewModel()
    @State private var showSignOutAlert = false

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeaderView()

                    if let profile = viewModel.state.userProfile {
                        UserProfileSectionView(profile: profile)
                    }

                    SectionHeaderView(title: "Cuenta")
                    if let profile = viewModel.state.userProfile {
                        AccountSectionView(profile: profile)
                    }

                    SectionHeaderView(title: "Descargas")
                    DownloadsSectionView(
                        pendingCount: viewModel.state.pendingSongsCount,
                        isGoogleDriveConfigured: viewModel.state.isGoogleDriveConfigured
                    )

                    SectionHeaderView(title: "Almacenamiento")
                    StorageSectionView(
                        totalStorage: viewModel.state.totalStorageUsed,
                        downloadedCount: viewModel.state.downloadedSongsCount,
                        onDeleteAll: {
                            viewModel.showDeleteAllAlert = true
                        }
                    )

                    SectionHeaderView(title: "Acerca de")
                    AboutSectionView(appVersion: "1.0.0")

                    SignOutButtonView {
                        showSignOutAlert = true
                    }
                }
            }
        }
        .onAppear {
            updateViewModel()
        }
        .onChange(of: songs) { _, _ in
            updateViewModel()
        }
        .alert("Eliminar todas las descargas", isPresented: $viewModel.showDeleteAllAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                handleDeleteAllDownloads()
            }
        } message: {
            Text("Se eliminarán \(viewModel.state.downloadedSongsCount) canciones descargadas. Esta acción no se puede deshacer.")
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

    private func updateViewModel() {
        viewModel.updateState(with: songs)
        viewModel.updateUserProfile(
            fullName: authManager.userFullName,
            email: authManager.userEmail,
            userID: authManager.userID
        )
    }

    private func handleDeleteAllDownloads() {
        Task {
            await viewModel.deleteAllDownloads(
                songs: songs,
                modelContext: modelContext,
                onCompletion: {
                    if playerViewModel.isPlaying {
                        playerViewModel.pause()
                    }
                }
            )
        }
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
