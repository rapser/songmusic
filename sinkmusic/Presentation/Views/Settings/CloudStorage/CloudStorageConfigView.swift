//
//  CloudStorageConfigView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Vista unificada para configurar proveedores de almacenamiento cloud
//

import SwiftUI

struct CloudStorageConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(SettingsViewModel.self) private var settingsVM

    private var settingsViewModel: SettingsViewModel {
        settingsVM
    }

    var body: some View {
        @Bindable var settings = settingsVM
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Almacenamiento Cloud")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Selecciona y configura tu proveedor de almacenamiento")
                            .font(.subheadline)
                            .foregroundColor(.textGray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Provider Selector
                    ProviderSelectorView(
                        selectedProvider: settings.selectedProvider,
                        hasGoogleDriveCredentials: settings.hasCredentials,
                        hasMegaCredentials: settings.hasMegaCredentials,
                        onProviderSelected: { provider in
                            settingsViewModel.setSelectedProvider(provider)
                        }
                    )
                    .padding(.horizontal, 16)

                    // Configuración del proveedor seleccionado
                    switch settings.selectedProvider {
                    case .googleDrive:
                        GoogleDriveConfigSection(settingsViewModel: settingsViewModel, libraryViewModel: libraryViewModel)
                    case .mega:
                        MegaConfigSection(settingsViewModel: settingsViewModel, libraryViewModel: libraryViewModel)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cerrar") {
                    dismiss()
                }
                .foregroundColor(.appPurple)
            }
        }
        .onAppear {
            settingsViewModel.loadCredentials()
        }
        .alert("Configuración Guardada", isPresented: $settings.showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Las credenciales se han guardado de forma segura")
        }
        .alert("Eliminar Credenciales", isPresented: $settings.showDeleteCredentialsAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task {
                    switch settings.selectedProvider {
                    case .googleDrive:
                        await settingsViewModel.deleteCredentialsAsync()
                    case .mega:
                        settingsViewModel.deleteMegaCredentials()
                    }
                    await libraryViewModel.clearLibrary()
                }
            }
        } message: {
            Text("Se eliminarán las credenciales y todas las canciones descargadas. Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Provider Selector

private struct ProviderSelectorView: View {
    let selectedProvider: CloudStorageProvider
    let hasGoogleDriveCredentials: Bool
    let hasMegaCredentials: Bool
    let onProviderSelected: (CloudStorageProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proveedor")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ProviderButton(
                    title: "Google Drive",
                    icon: "g.circle.fill",
                    isSelected: selectedProvider == .googleDrive,
                    isConfigured: hasGoogleDriveCredentials,
                    action: { onProviderSelected(.googleDrive) }
                )

                ProviderButton(
                    title: "Mega",
                    icon: "m.circle.fill",
                    isSelected: selectedProvider == .mega,
                    isConfigured: hasMegaCredentials,
                    action: { onProviderSelected(.mega) }
                )
            }
        }
    }
}

private struct ProviderButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isConfigured: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(isSelected ? .appPurple : .textGray)

                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .offset(x: 4, y: -4)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .textGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.appPurple.opacity(0.2) : Color.appGray)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appPurple : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Google Drive Config Section

private struct GoogleDriveConfigSection: View {
    let settingsViewModel: SettingsViewModel
    let libraryViewModel: LibraryViewModel

    var body: some View {
        @Bindable var settings = settingsViewModel
        VStack(alignment: .leading, spacing: 16) {
            // Instrucciones
            InstructionsCard()

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("API Key de Google")
                        .font(.headline)
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "key.fill")
                        .foregroundColor(.appPurple)
                }

                TextField("", text: $settings.apiKey, prompt: Text("Ingresa tu API Key").foregroundColor(.textGray))
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 16)

            // Folder ID
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("ID de Carpeta")
                        .font(.headline)
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.appPurple)
                }

                TextField("", text: $settings.folderId, prompt: Text("Ingresa el ID de la carpeta").foregroundColor(.textGray))
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 16)

            // Estado actual
            if settingsViewModel.hasExistingCredentials {
                ConfiguredStatusView()
                    .padding(.horizontal, 16)
            }

            // Botones
            ActionButtonsView(
                canSave: settingsViewModel.areCredentialsValid,
                hasCredentials: settingsViewModel.hasExistingCredentials,
                onSave: {
                    Task {
                        let success = await settingsViewModel.saveCredentialsAsync()
                        if success {
                            await libraryViewModel.loadSongs()
                        }
                    }
                },
                onDelete: {
                    settingsViewModel.showDeleteCredentialsAlert = true
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Mega Config Section

private struct MegaConfigSection: View {
    let settingsViewModel: SettingsViewModel
    let libraryViewModel: LibraryViewModel

    var body: some View {
        @Bindable var settings = settingsViewModel
        VStack(alignment: .leading, spacing: 16) {
            // Instrucciones para Mega
            MegaInstructionsCard()

            // Folder URL + botón escanear QR
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("URL de Carpeta Pública")
                        .font(.headline)
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "link")
                        .foregroundColor(.appPurple)
                }

                HStack(spacing: 12) {
                    TextField("", text: $settings.megaFolderURL, prompt: Text("https://mega.nz/folder/...").foregroundColor(.textGray))
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    Button {
                        settings.showQRScanner = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.appPurple)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .sheet(isPresented: $settings.showQRScanner) {
                NavigationStack {
                    QRCodeScannerView { url in
                        settings.megaFolderURL = url
                        settings.showQRScanner = false
                    }
                }
            }

            // Estado actual
            if settingsViewModel.hasMegaCredentials {
                ConfiguredStatusView()
                    .padding(.horizontal, 16)
            }

            // Botones
            ActionButtonsView(
                canSave: settingsViewModel.validateMegaFolderURL(),
                hasCredentials: settingsViewModel.hasMegaCredentials,
                onSave: {
                    Task {
                        let success = settingsViewModel.saveMegaFolderURL()
                        if success {
                            settingsViewModel.showSaveConfirmation = true
                            await libraryViewModel.loadSongs()
                        }
                    }
                },
                onDelete: {
                    settingsViewModel.showDeleteCredentialsAlert = true
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Mega Instructions Card

private struct MegaInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Cómo obtener la URL de Mega")
                    .font(.headline)
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.appPurple)
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionStep(number: 1, text: "Abre mega.nz en tu navegador")
                InstructionStep(number: 2, text: "Navega a la carpeta con tu música")
                InstructionStep(number: 3, text: "Haz clic derecho > Obtener enlace (o comparte por QR)")
                InstructionStep(number: 4, text: "Asegúrate que sea un enlace público")
                InstructionStep(number: 5, text: "Copia la URL o escanea el código QR con el botón de cámara")
            }

            Text("Ejemplo: https://mega.nz/folder/ABC123#key456")
                .font(.caption)
                .foregroundColor(.textGray)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.appGray)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Reusable Components

private struct ConfiguredStatusView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.appPurple)
            Text("Credenciales configuradas correctamente")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.appGray)
        .cornerRadius(8)
    }
}

private struct ActionButtonsView: View {
    let canSave: Bool
    let hasCredentials: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Botón Guardar
            Button(action: onSave) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Guardar Configuración")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(canSave ? Color.appPurple : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canSave)

            // Botón Eliminar
            if hasCredentials {
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Eliminar Credenciales")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        settingsVM: PreviewViewModels.settingsVM()
    ) {
        NavigationStack {
            CloudStorageConfigView()
        }
    }
}
