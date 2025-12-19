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
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)
            
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
                            .foregroundColor(.textGray)
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
                                .foregroundColor(.appPurple)
                        }
                        
                        TextField("", text: $settingsViewModel.apiKey, prompt: Text("Ingresa tu API Key").foregroundColor(.textGray))
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
                        
                        TextField("", text: $settingsViewModel.folderId, prompt: Text("Ingresa el ID de la carpeta").foregroundColor(.textGray))
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16)
                    
                    // Estado actual
                    if settingsViewModel.hasExistingCredentials {
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
                        .padding(.horizontal, 16)
                    }
                    
                    // Botones
                    VStack(spacing: 12) {
                        // Botón Guardar
                        Button(action: {
                            settingsViewModel.saveCredentials(modelContext: modelContext, mainViewModel: mainViewModel)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar Configuración")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(settingsViewModel.areCredentialsValid ? Color.appPurple : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!settingsViewModel.areCredentialsValid)
                        
                        // Botón Eliminar
                        if settingsViewModel.hasExistingCredentials {
                            Button(action: { settingsViewModel.showDeleteCredentialsAlert = true }) {
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
                .foregroundColor(.appPurple)
            }
        }
        .onAppear {
            settingsViewModel.loadCredentials()
        }
        .alert("Configuración Guardada", isPresented: $settingsViewModel.showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Las credenciales se han guardado de forma segura en Keychain")
        }
        .alert("Eliminar Credenciales", isPresented: $settingsViewModel.showDeleteCredentialsAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                settingsViewModel.deleteCredentials(modelContext: modelContext, mainViewModel: mainViewModel)
            }
        } message: {
            Text("Se eliminarán las credenciales de Google Drive y todas las canciones descargadas. Esta acción no se puede deshacer.")
        }
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
                        .foregroundColor(.appPurple)

                    Text("¿Cómo obtener estas credenciales?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.textGray)
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
                        .foregroundColor(.textGray)
                        .padding(.top, 4)

                    Text("drive.google.com/drive/folders/[FOLDER_ID]")
                        .font(.caption)
                        .foregroundColor(.appPurple)
                        .padding(8)
                        .background(Color.appGray.opacity(0.5))
                        .cornerRadius(4)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.appGray)
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
                .foregroundColor(.appPurple)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.textGray)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(12)
            .background(Color.appGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.textGray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        GoogleDriveConfigView()
    }
}
