import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var showDeleteAllAlert = false

    var pendingSongs: [Song] {
        songs.filter { !$0.isDownloaded }
    }

    var downloadedSongs: [Song] {
        songs.filter { $0.isDownloaded }
    }

    var totalStorageUsed: String {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        for song in downloadedSongs {
            if let localURL = GoogleDriveService().localURL(for: song.id),
               fileManager.fileExists(atPath: localURL.path) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                } catch {
                    continue
                }
            }
        }

        return formatBytes(totalSize)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
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
                        clearColorCache()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.appPurple)
                                .frame(width: 24, height: 24)

                            Text("Limpiar caché de colores")
                                .font(.body)
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.appGray)
                    }

                    Button(action: {
                        showDeleteAllAlert = true
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
                        authManager.signOut()
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
        .alert("Eliminar todas las descargas", isPresented: $showDeleteAllAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                deleteAllDownloads()
            }
        } message: {
            Text("Se eliminarán \(downloadedSongs.count) canciones descargadas. Esta acción no se puede deshacer.")
        }
    }

    private func deleteAllDownloads() {
        Task {
            // Pausar reproducción si hay algo tocando
            if playerViewModel.isPlaying {
                playerViewModel.pause()
            }

            for song in downloadedSongs {
                // Eliminar el archivo descargado
                do {
                    try DownloadService().deleteDownload(for: song.id)
                } catch {
                    print("Error al eliminar descarga de \(song.title): \(error)")
                }

                // Resetear los datos de la canción
                song.isDownloaded = false
                song.duration = nil
                song.artworkData = nil
                song.album = nil
                song.author = nil
            }

            // Guardar todos los cambios
            do {
                try modelContext.save()
                print("✅ Todas las descargas eliminadas exitosamente")
            } catch {
                print("❌ Error al guardar cambios: \(error)")
            }
        }
    }

    private func clearColorCache() {
        for song in songs {
            song.cachedDominantColorRed = nil
            song.cachedDominantColorGreen = nil
            song.cachedDominantColorBlue = nil
        }
        
        do {
            try modelContext.save()
            print("✅ Caché de colores limpiado exitosamente")
        } catch {
            print("❌ Error al limpiar caché: \(error)")
        }
    }
}

// MARK: - Components

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.textGray)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.textGray)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.white)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.textGray)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.textGray)
                .font(.caption)
        }
        .padding(16)
        .background(Color.appGray)
    }
}

struct SettingsToggleView: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.textGray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textGray)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .appPurple))
        }
        .padding(16)
        .background(Color.appGray)
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM()
    ) {
        SettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
}
