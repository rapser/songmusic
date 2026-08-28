//
//  DownloadFileStore.swift
//  sinkmusic
//
//  Infrastructure Layer
//

import Foundation

/// Implementación de `DownloadFileStoreProtocol` sobre `FileManager`.
/// Único punto de la app que conoce la ruta `Documents/Music/<uuid>.m4a`.
final class DownloadFileStore: DownloadFileStoreProtocol {

    private static let musicFolderName = "Music"
    private static let fileExtension = "m4a"

    private var musicDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(Self.musicFolderName)
    }

    func fileURL(for songID: UUID) -> URL {
        musicDirectory
            .appendingPathComponent(songID.uuidString)
            .appendingPathExtension(Self.fileExtension)
    }

    func existingFileURL(for songID: UUID) -> URL? {
        let url = fileURL(for: songID)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

// FileManager es thread-safe para estas operaciones de solo-lectura de rutas.
extension DownloadFileStore: @unchecked Sendable {}
