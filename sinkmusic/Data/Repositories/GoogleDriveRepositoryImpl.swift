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
        // Necesitamos obtener el SongDTO para pasarlo al servicio
        guard let songDTO = try songLocalDataSource.getByID(songID) else {
            throw NSError(
                domain: "GoogleDriveRepositoryImpl",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Song not found with ID: \(songID)"]
            )
        }

        // Llamar al servicio de descarga
        return try await googleDriveService.download(
            song: songDTO,
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
