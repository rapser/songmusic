//
//  SettingsView.swift
//  sinkmusic
//
//  Pantalla de Ajustes: layout propio (ScrollView + tarjetas) en lugar de `List`,
//  para controlar el alto de cada fila y el espaciado entre secciones — `List`
//  imponía filas de ~44pt y secciones muy separadas.
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

    // MARK: - Métricas del layout compacto
    private enum Metrics {
        static let sectionSpacing: CGFloat = 16
        static let rowSpacing: CGFloat = 2
        static let cardCornerRadius: CGFloat = 12
        static let cardInsetV: CGFloat = 4
        static let cardInsetH: CGFloat = 10
        static let horizontalMargin: CGFloat = 16
    }

    var body: some View {
        ZStack {
            Color.appDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    SettingsHeaderView()

                    if let profile = makeUserProfile() {
                        card {
                            UserProfileSectionView(profile: profile)
                        }
                    }

                    if let profile = makeUserProfile() {
                        section("Cuenta") {
                            AccountSectionView(profile: profile)
                        }
                    }

                    section("Inicio") {
                        NavigationLink(destination: HomePlaylistsOrderView()) {
                            SettingsRowView(
                                icon: "rectangle.stack.fill",
                                iconColor: .appPurple,
                                title: "Playlists en Inicio",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    section("Descargas") {
                        DownloadsSectionView(
                            pendingCount: pendingSongsCount,
                            isGoogleDriveConfigured: viewModel.hasCredentials,
                            libraryViewModel: libraryViewModel,
                            settingsViewModel: viewModel
                        )
                    }

                    section("Almacenamiento") {
                        StorageSectionView(
                            totalStorage: viewModel.storageInfo?.formattedTotalSize ?? "0 MB",
                            downloadedCount: viewModel.downloadStats?.totalDownloaded ?? 0,
                            onDeleteAll: { showDeleteAllAlert = true }
                        )
                    }

                    section("Acerca de") {
                        AboutSectionView(appVersion: viewModel.appInfo?.fullVersion ?? "1.0.0")
                    }

                    card {
                        SignOutButtonView { showSignOutAlert = true }
                    }

                    // Espacio inferior para que el mini-reproductor no tape "Cerrar sesión".
                    Color.clear.frame(height: playerViewModel.currentlyPlayingID != nil ? 96 : 12)
                }
                .padding(.horizontal, Metrics.horizontalMargin)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await viewModel.loadAllInfo()
        }
        .alert("Eliminar todas las descargas", isPresented: $showDeleteAllAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task { await handleDeleteAllDownloads() }
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

    // MARK: - Section builders

    /// Sección con título en mayúsculas + tarjeta compacta con las filas.
    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.textGray)
                .padding(.leading, 6)

            card { content() }
        }
    }

    /// Tarjeta redondeada que agrupa filas con espaciado mínimo entre ellas.
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Metrics.rowSpacing) {
            content()
        }
        .padding(.vertical, Metrics.cardInsetV)
        .padding(.horizontal, Metrics.cardInsetH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
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
        libraryViewModel.songs.filter { !$0.isDownloaded }.count
    }

    private func handleDeleteAllDownloads() async {
        if playerViewModel.isPlaying {
            await playerViewModel.pause()
        }
        await viewModel.deleteAllDownloads()
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
