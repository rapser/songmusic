//
//  CloudStorageRepositoryImpl.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Cloud Storage
/// Encapsula DataSources de cloud (GoogleDrive, OneDrive, etc.) y adapta su interfaz al dominio
@MainActor
final class CloudStorageRepositoryImpl: CloudStorageRepositoryProtocol {

    // MARK: - Dependencies

    private let googleDriveDataSource: GoogleDriveServiceProtocol
    private let songLocalDataSource: SongLocalDataSource

    // MARK: - Initialization

    init(
        googleDriveDataSource: GoogleDriveServiceProtocol,
        songLocalDataSource: SongLocalDataSource
    ) {
        self.googleDriveDataSource = googleDriveDataSource
        self.songLocalDataSource = songLocalDataSource
    }

    // MARK: - CloudStorageRepositoryProtocol

    func fetchSongsFromFolder() async throws -> [CloudFileEntity] {
        // Por ahora solo soporta Google Drive
        // En el futuro se puede agregar lógica para elegir el proveedor
        let googleDriveFiles = try await googleDriveDataSource.fetchSongsFromFolder()
        return CloudFileMapper.toEntities(from: googleDriveFiles)
    }

    func download(
        fileID: String,
        songID: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL {
        // Por ahora solo Google Drive
        // En el futuro: switch basado en el proveedor seleccionado
        return try await googleDriveDataSource.download(
            fileID: fileID,
            songID: songID,
            progressCallback: progressCallback
        )
    }

    func getDuration(for url: URL) -> TimeInterval? {
        return googleDriveDataSource.getDuration(for: url)
    }

    func deleteDownload(for songID: UUID) throws {
        try googleDriveDataSource.deleteDownload(for: songID)
    }

    func localURL(for songID: UUID) -> URL? {
        return googleDriveDataSource.localURL(for: songID)
    }
}

// MARK: - Sendable Conformance

extension CloudStorageRepositoryImpl: Sendable {}

// MARK: - Provider Selection (Future Enhancement)

extension CloudStorageRepositoryImpl {
    /// En el futuro, se puede agregar lógica para cambiar de proveedor dinámicamente:
    ///
    /// ```swift
    /// enum CloudProvider {
    ///     case googleDrive(GoogleDriveDataSource)
    ///     case oneDrive(OneDriveDataSource)
    ///     case mega(MegaDataSource)
    /// }
    ///
    /// private var currentProvider: CloudProvider
    ///
    /// func switchProvider(to provider: CloudProvider) {
    ///     self.currentProvider = provider
    /// }
    /// ```
}
