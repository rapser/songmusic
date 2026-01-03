//
//  RefactoredSettingsView.swift
//  sinkmusic
//
//  DEPRECATED - Legacy file
//  Este archivo ya no se usa. La vista activa es SettingsView.swift
//  que usa Clean Architecture con SettingsViewModel del DIContainer.
//

import SwiftUI
import SwiftData

// MARK: - DEPRECATED - Legacy Refactored Settings View

/// ⚠️ DEPRECATED: Este archivo ya no se usa.
/// Usar SettingsView.swift en su lugar, que utiliza Clean Architecture.
@available(*, deprecated, message: "Use SettingsView.swift instead")
struct RefactoredSettingsView: View {
    // MARK: - Environment & Dependencies

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]

    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    // MARK: - State (Swift 6)

    @State private var viewModel = RefactoredSettingsViewModel()
    @State private var showSignOutAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HeaderView()

                    // User Profile Section
                    if let profile = viewModel.state.userProfile {
                        UserProfileSectionView(profile: profile)
                    }

                    // Account Section
                    SectionHeaderView(title: "Cuenta")
                    if let profile = viewModel.state.userProfile {
                        AccountSectionView(profile: profile)
                    }

                    // Downloads Section
                    SectionHeaderView(title: "Descargas")
                    DownloadsSectionView(
                        pendingCount: viewModel.state.pendingSongsCount,
                        isGoogleDriveConfigured: viewModel.state.isGoogleDriveConfigured
                    )

                    // Storage Section
                    SectionHeaderView(title: "Almacenamiento")
                    StorageSectionView(
                        totalStorage: viewModel.state.totalStorageUsed,
                        downloadedCount: viewModel.state.downloadedSongsCount,
                        onDeleteAll: {
                            viewModel.showDeleteAllAlert = true
                        }
                    )

                    // About Section
                    SectionHeaderView(title: "Acerca de")
                    AboutSectionView(appVersion: "1.0.0")

                    // Sign Out Button
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

    // MARK: - Private Methods

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
                    // Pausar el reproductor si está tocando
                    if playerViewModel.isPlaying {
                        playerViewModel.pause()
                    }
                }
            )
        }
    }
}

// MARK: - Header View

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

// MARK: - Preview

#Preview {
    PreviewWrapper {
        RefactoredSettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
}
