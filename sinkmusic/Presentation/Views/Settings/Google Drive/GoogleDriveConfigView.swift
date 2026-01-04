//
//  GoogleDriveConfigView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct GoogleDriveConfigView: View {
    @Environment(\.dismiss) private var dismiss

    let libraryViewModel: LibraryViewModel
    let settingsViewModel: SettingsViewModel
    
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
                            Task {
                                let success = await settingsViewModel.saveCredentialsAsync()
                                if success {
                                    await libraryViewModel.loadSongs()
                                }
                            }
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
                Task {
                    await settingsViewModel.deleteCredentialsAsync()
                    await libraryViewModel.clearLocalSongs()
                }
            }
        } message: {
            Text("Se eliminarán las credenciales de Google Drive y todas las canciones descargadas. Esta acción no se puede deshacer.")
        }
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        settingsVM: PreviewViewModels.settingsVM()
    ) {
        NavigationStack {
            GoogleDriveConfigView(
                libraryViewModel: PreviewViewModels.libraryVM(),
                settingsViewModel: PreviewViewModels.settingsVM()
            )
        }
    }
}
