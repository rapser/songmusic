//
//  GoogleDriveConfigView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct GoogleDriveConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mainViewModel: MainViewModel
    @State private var apiKey: String = ""
    @State private var folderId: String = ""
    @State private var showSaveConfirmation = false
    @State private var hasExistingCredentials = false

    private let keychainService = KeychainService.shared

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configuración de Google Drive")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Configura tus credenciales para acceder a Google Drive")
                            .font(.subheadline)
                            .foregroundColor(.spotifyLightGray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

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
                                .foregroundColor(.spotifyGreen)
                        }

                        TextField("", text: $apiKey, prompt: Text("Ingresa tu API Key").foregroundColor(.spotifyLightGray))
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
                                .foregroundColor(.spotifyGreen)
                        }

                        TextField("", text: $folderId, prompt: Text("Ingresa el ID de la carpeta").foregroundColor(.spotifyLightGray))
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16)

                    // Estado actual
                    if hasExistingCredentials {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.spotifyGreen)
                            Text("Credenciales configuradas correctamente")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color.spotifyGray)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }

                    // Botones
                    VStack(spacing: 12) {
                        // Botón Guardar
                        Button(action: saveCredentials) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar Configuración")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(apiKey.isEmpty || folderId.isEmpty ? Color.gray : Color.spotifyGreen)
                            .cornerRadius(12)
                        }
                        .disabled(apiKey.isEmpty || folderId.isEmpty)

                        // Botón Eliminar
                        if hasExistingCredentials {
                            Button(action: deleteCredentials) {
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cerrar") {
                    dismiss()
                }
                .foregroundColor(.spotifyGreen)
            }
        }
        .onAppear {
            loadCredentials()
        }
        .alert("Configuración Guardada", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Las credenciales se han guardado de forma segura en Keychain")
        }
    }

    // MARK: - Actions

    private func loadCredentials() {
        if let savedAPIKey = keychainService.googleDriveAPIKey {
            apiKey = savedAPIKey
            hasExistingCredentials = true
        } else {
            apiKey = ""
        }

        if let savedFolderId = keychainService.googleDriveFolderId {
            folderId = savedFolderId
        } else {
            folderId = ""
        }
    }

    private func saveCredentials() {
        let apiKeySaved = keychainService.save(apiKey, for: .googleDriveAPIKey)
        let folderIdSaved = keychainService.save(folderId, for: .googleDriveFolderId)

        if apiKeySaved && folderIdSaved {
            hasExistingCredentials = true
            showSaveConfirmation = true
            print("✅ Credenciales guardadas en Keychain")
        } else {
            print("❌ Error al guardar credenciales")
        }
    }

    private func deleteCredentials() {
        keychainService.delete(for: .googleDriveAPIKey)
        keychainService.delete(for: .googleDriveFolderId)
        apiKey = ""
        folderId = ""
        hasExistingCredentials = false
        mainViewModel.clearLibrary(modelContext: modelContext)
        print("🗑️ Credenciales eliminadas del Keychain y biblioteca local limpiada.")
    }
}

// MARK: - Components

struct InstructionsCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.spotifyGreen)

                    Text("¿Cómo obtener estas credenciales?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.spotifyLightGray)
                        .font(.caption)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "Ve a Google Cloud Console")
                    InstructionStep(number: 2, text: "Crea un proyecto y habilita la API de Google Drive")
                    InstructionStep(number: 3, text: "Genera una API Key en 'Credenciales'")
                    InstructionStep(number: 4, text: "El Folder ID está en la URL de tu carpeta compartida de Drive")

                    Text("Ejemplo de URL:")
                        .font(.caption)
                        .foregroundColor(.spotifyLightGray)
                        .padding(.top, 4)

                    Text("drive.google.com/drive/folders/[FOLDER_ID]")
                        .font(.caption)
                        .foregroundColor(.spotifyGreen)
                        .padding(8)
                        .background(Color.spotifyGray.opacity(0.5))
                        .cornerRadius(4)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.spotifyGray)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.spotifyGreen)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.spotifyLightGray)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(12)
            .background(Color.spotifyGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.spotifyLightGray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        GoogleDriveConfigView()
    }
}
