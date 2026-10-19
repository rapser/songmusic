//
//  CloudCredentialsUseCases.swift
//  sinkmusic
//
//  Domain Layer - UseCase
//

import Foundation

/// A qué nube apunta la app y si las credenciales sirven.
///
/// Salió de `SettingsUseCases`, que además borraba datos y leía la versión del bundle: tres
/// motivos de cambio sin nada en común más que compartir pantalla. Aquí queda uno solo, y
/// las dos únicas dependencias que ese motivo necesita.
///
/// Cada proveedor guarda credenciales de forma distinta —Google Drive una API key y un id de
/// carpeta, Mega una URL con la clave en el fragmento—, así que los métodos están separados
/// por proveedor en vez de forzar una forma común que la UI no tiene.
@MainActor
final class CloudCredentialsUseCases: Sendable {

    private let credentialsRepository: CredentialsRepositoryProtocol
    private let cloudStorageRepository: CloudStorageRepositoryProtocol

    init(
        credentialsRepository: CredentialsRepositoryProtocol,
        cloudStorageRepository: CloudStorageRepositoryProtocol
    ) {
        self.credentialsRepository = credentialsRepository
        self.cloudStorageRepository = cloudStorageRepository
    }

    // MARK: - Google Drive

    func loadGoogleDriveCredentials() -> (apiKey: String, folderId: String, hasCredentials: Bool) {
        credentialsRepository.loadGoogleDriveCredentials()
    }

    /// Guarda la API key y el id de carpeta ya recortados. Devuelve `false` si alguno viene
    /// vacío: no tiene sentido persistir credenciales a medias.
    func saveGoogleDriveCredentials(apiKey: String, folderId: String) -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        let trimmedFolder = folderId.trimmingCharacters(in: .whitespaces)

        guard !trimmedKey.isEmpty, !trimmedFolder.isEmpty else { return false }

        return credentialsRepository.saveGoogleDriveCredentials(
            apiKey: trimmedKey,
            folderId: trimmedFolder
        )
    }

    func deleteGoogleDriveCredentials() {
        credentialsRepository.deleteGoogleDriveCredentials()
    }

    func hasGoogleDriveCredentials() -> Bool {
        credentialsRepository.hasGoogleDriveCredentials()
    }

    // MARK: - Mega

    func loadMegaFolderURL() -> String {
        credentialsRepository.loadMegaFolderURL()
    }

    func saveMegaFolderURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, validateMegaFolderURL(trimmed) else { return false }
        return credentialsRepository.saveMegaFolderURL(trimmed)
    }

    func deleteMegaCredentials() {
        credentialsRepository.deleteMegaCredentials()
    }

    func hasMegaCredentials() -> Bool {
        credentialsRepository.hasMegaCredentials()
    }

    // MARK: - Provider Selection

    func getSelectedCloudProvider() -> CloudStorageProvider {
        credentialsRepository.getSelectedCloudProvider()
    }

    func setSelectedCloudProvider(_ provider: CloudStorageProvider) {
        credentialsRepository.setSelectedCloudProvider(provider)
    }

    /// Si el proveedor activo ahora mismo está configurado. Es lo que decide si se puede
    /// sincronizar o hay que mandar al usuario a Ajustes.
    func hasCurrentProviderCredentials() -> Bool {
        switch getSelectedCloudProvider() {
        case .googleDrive: return hasGoogleDriveCredentials()
        case .mega: return hasMegaCredentials()
        }
    }

    // MARK: - Validation

    /// Validación de forma, no de autenticidad: solo evita mandar a la red algo que no
    /// puede ser una credencial. Quien dice la última palabra es
    /// `testCloudStorageConnection()`.

    /// Las API keys de Google rondan los 39 caracteres.
    func validateAPIKey(_ apiKey: String) -> Bool {
        apiKey.trimmingCharacters(in: .whitespaces).count >= 30
    }

    /// Los ids de carpeta de Drive rondan los 25-50 caracteres.
    func validateFolderID(_ folderId: String) -> Bool {
        folderId.trimmingCharacters(in: .whitespaces).count >= 20
    }

    /// Formato `https://mega.nz/folder/{nodeId}#{key}`. Sin el fragmento no hay clave de
    /// descifrado y la carpeta no se puede leer, así que se exige.
    func validateMegaFolderURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("https://mega.nz/folder/") && trimmed.contains("#")
    }

    // MARK: - Connection Test

    /// Prueba las credenciales contra la nube de verdad: lista la carpeta configurada.
    func testCloudStorageConnection() async throws -> Bool {
        do {
            _ = try await cloudStorageRepository.fetchSongsFromFolder()
            return true
        } catch {
            throw SettingsError.connectionFailed(error)
        }
    }
}
