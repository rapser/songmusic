//
//  GoogleDriveRepositoryImpl.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Google Drive
/// Encapsula el GoogleDriveService y adapta su interfaz al dominio
@MainActor
final class GoogleDriveRepositoryImpl: GoogleDriveRepositoryProtocol {

    // MARK: - Dependencies

    private let googleDriveService: GoogleDriveService
    private let songLocalDataSource: SongLocalDataSource

    // MARK: - Initialization

    init(googleDriveService: GoogleDriveService, songLocalDataSource: SongLocalDataSource) {
        self.googleDriveService = googleDriveService
        self.songLocalDataSource = songLocalDataSource
    }

    // MARK: - GoogleDriveRepositoryProtocol

    func fetchSongsFromFolder() async throws -> [GoogleDriveFile] {
        return try await googleDriveService.fetchSongsFromFolder()
    }

    func download(
        fileID: String,
        songID: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL {
        // Llamar al servicio de descarga con los parámetros directos
        return try await googleDriveService.download(
            fileID: fileID,
            songID: songID,
            progressCallback: progressCallback
        )
    }

    func getDuration(for url: URL) -> TimeInterval? {
        return googleDriveService.getDuration(for: url)
    }

    func deleteDownload(for songID: UUID) throws {
        try googleDriveService.deleteDownload(for: songID)
    }

    func localURL(for songID: UUID) -> URL? {
        return googleDriveService.localURL(for: songID)
    }
}

// MARK: - Sendable Conformance

extension GoogleDriveRepositoryImpl: Sendable {}
