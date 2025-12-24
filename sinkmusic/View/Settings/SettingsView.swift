import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showSignOutAlert = false

    var pendingSongs: [Song] {
        settingsViewModel.filterPendingSongs(songs)
    }

    var downloadedSongs: [Song] {
        settingsViewModel.filterDownloadedSongs(songs)
    }

    var totalStorageUsed: String {
        settingsViewModel.calculateTotalStorageUsed(for: songs)
    }

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Configuración")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                    // Perfil de usuario
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.appPurple)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.userFullName ?? "Usuario Premium")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(authManager.userEmail ?? "Ver perfil")
                                    .font(.subheadline)
                                    .foregroundColor(.textGray)
                            }

                            Spacer()

                            Image(systemName: "apple.logo")
                                .foregroundColor(.textGray)
                        }
                        .padding(16)
                        .background(Color.appGray)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Sección: Cuenta
                    SectionHeaderView(title: "Cuenta")

                    if let email = authManager.userEmail {
                        SettingsRowView(icon: "envelope.fill", title: "Correo electrónico", value: email)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.textGray)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Correo electrónico")
                                        .foregroundColor(.white)
                                    Text("No compartido por Apple")
                                        .font(.caption)
                                        .foregroundColor(.textGray)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(Color.appGray)
                        }
                    }

                    if let userID = authManager.userID {
                        SettingsRowView(icon: "person.text.rectangle.fill", title: "ID de usuario", value: String(userID.prefix(12)))
                    }

                    SettingsRowView(icon: "apple.logo", title: "Cuenta Apple", value: "Conectada")

                    // Sección: Descargas
                    SectionHeaderView(title: "Descargas")

                    NavigationLink(destination: DownloadMusicView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.textGray)
                                .frame(width: 24)

                            Text("Descargar música")
                                .foregroundColor(.white)

                            Spacer()

                            if !pendingSongs.isEmpty {
                                Text("\(pendingSongs.count)")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.appPurple)
                                    .cornerRadius(12)
                            }

                            Image(systemName: "chevron.right")
                                .foregroundColor(.textGray)
                                .font(.caption)
                        }
                        .padding(16)
                        .background(Color.appGray)
                    }

                    NavigationLink(destination: GoogleDriveConfigView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.textGray)
                                .frame(width: 24)

                            Text("Configurar Google Drive")
                                .foregroundColor(.white)

                            Spacer()

                            if KeychainService.shared.hasGoogleDriveCredentials {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.appPurple)
                            }

                            Image(systemName: "chevron.right")
                                .foregroundColor(.textGray)
                                .font(.caption)
                        }
                        .padding(16)
                        .background(Color.appGray)
                    }

                    // Sección: Almacenamiento
                    SectionHeaderView(title: "Almacenamiento")

                    SettingsRowView(
                        icon: "internaldrive.fill",
                        title: "Espacio usado",
                        value: totalStorageUsed
                    )

                    Button(action: {
                        settingsViewModel.showDeleteAllAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Eliminar todas las descargas")
                                    .font(.body)
                                    .foregroundColor(.white)

                                if !downloadedSongs.isEmpty {
                                    Text("\(downloadedSongs.count) canciones descargadas")
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
                    .disabled(downloadedSongs.isEmpty)

                    // Sección: Acerca de
                    SectionHeaderView(title: "Acerca de")

                    SettingsRowView(icon: "info.circle.fill", title: "Versión", value: "1.0.0")
                    SettingsRowView(icon: "doc.text.fill", title: "Términos y condiciones")
                    SettingsRowView(icon: "hand.raised.fill", title: "Política de privacidad")

                    // Botón Cerrar sesión
                    Button(action: {
                        showSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.white)
                                .frame(width: 24)
                            Text("Cerrar sesión")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .alert("Eliminar todas las descargas", isPresented: $settingsViewModel.showDeleteAllAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task {
                    await settingsViewModel.deleteAllDownloads(
                        songs: songs,
                        modelContext: modelContext,
                        playerViewModel: playerViewModel
                    )
                }
            }
        } message: {
            Text("Se eliminarán \(downloadedSongs.count) canciones descargadas. Esta acción no se puede deshacer.")
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

}

#Preview {
    PreviewWrapper {
        SettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
}
