import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var notificationsEnabled = true
    @State private var downloadQuality = 1
    @State private var streamingQuality = 1
    @State private var offlineMode = false
    @State private var showExplicitContent = true

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

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
                                .foregroundColor(.spotifyGreen)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Usuario Premium")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Ver perfil")
                                    .font(.subheadline)
                                    .foregroundColor(.spotifyLightGray)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.spotifyLightGray)
                        }
                        .padding(16)
                        .background(Color.spotifyGray)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Sección: Cuenta
                    SectionHeaderView(title: "Cuenta")

                    SettingsRowView(icon: "envelope.fill", title: "Correo electrónico", value: "usuario@taki.com")
                    SettingsRowView(icon: "lock.fill", title: "Cambiar contraseña")
                    SettingsRowView(icon: "creditcard.fill", title: "Suscripción", value: "Premium")

                    // Sección: Calidad de audio
                    SectionHeaderView(title: "Calidad de audio")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.spotifyLightGray)
                                .frame(width: 24)
                            Text("Calidad de descarga")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        Picker("Calidad de descarga", selection: $downloadQuality) {
                            Text("Baja").tag(0)
                            Text("Normal").tag(1)
                            Text("Alta").tag(2)
                            Text("Muy alta").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 8)
                    .background(Color.spotifyGray)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.spotifyLightGray)
                                .frame(width: 24)
                            Text("Calidad de streaming")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        Picker("Calidad de streaming", selection: $streamingQuality) {
                            Text("Baja").tag(0)
                            Text("Normal").tag(1)
                            Text("Alta").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 8)
                    .background(Color.spotifyGray)

                    // Sección: Reproducción
                    SectionHeaderView(title: "Reproducción")

                    SettingsToggleView(
                        icon: "bell.fill",
                        title: "Notificaciones",
                        subtitle: "Recibe notificaciones de nuevas canciones",
                        isOn: $notificationsEnabled
                    )

                    SettingsToggleView(
                        icon: "arrow.down.circle.fill",
                        title: "Modo offline",
                        subtitle: "Solo reproduce música descargada",
                        isOn: $offlineMode
                    )

                    SettingsToggleView(
                        icon: "exclamationmark.triangle.fill",
                        title: "Contenido explícito",
                        subtitle: "Permitir canciones con contenido explícito",
                        isOn: $showExplicitContent
                    )

                    // Sección: Almacenamiento
                    SectionHeaderView(title: "Almacenamiento")

                    SettingsRowView(
                        icon: "internaldrive.fill",
                        title: "Espacio usado",
                        value: "2.4 GB"
                    )

                    SettingsRowView(
                        icon: "trash.fill",
                        title: "Eliminar caché"
                    )

                    // Sección: Acerca de
                    SectionHeaderView(title: "Acerca de")

                    SettingsRowView(icon: "info.circle.fill", title: "Versión", value: "1.0.0")
                    SettingsRowView(icon: "doc.text.fill", title: "Términos y condiciones")
                    SettingsRowView(icon: "hand.raised.fill", title: "Política de privacidad")

                    // Botón Cerrar sesión
                    Button(action: {
                        // Acción de cerrar sesión
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
    }
}

// MARK: - Components

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.spotifyLightGray)
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
                .foregroundColor(.spotifyLightGray)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.white)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.spotifyLightGray)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.spotifyLightGray)
                .font(.caption)
        }
        .padding(16)
        .background(Color.spotifyGray)
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
                .foregroundColor(.spotifyLightGray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .spotifyGreen))
        }
        .padding(16)
        .background(Color.spotifyGray)
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM()
    ) {
        SettingsView()
    }
}
