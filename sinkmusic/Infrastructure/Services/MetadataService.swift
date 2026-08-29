//
//  MetadataService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import AVFoundation
import UIKit
import OSLog

// SongMetadata is defined in Domain/RepositoryProtocols/MetadataRepositoryProtocol.swift

/// Servicio para extraer metadatos de archivos de audio
/// Implementa MetadataServiceProtocol cumpliendo con SOLID
final class MetadataService: MetadataServiceProtocol {

    private static let logger = Logger(subsystem: "com.sinkmusic.app", category: "MetadataService")

    /// Límite de tiempo para leer metadata. `AVURLAsset.load(.duration)` sobre un MP3 VBR
    /// sin cabecera fuerza un escaneo del archivo entero, y un archivo malformado puede
    /// colgar indefinidamente — lo que antes bloqueaba `downloadSong` y toda la cola.
    private static let timeout: Duration = .seconds(8)

    /// Extrae los metadatos de un archivo de audio local.
    /// Si el archivo no es válido, la lectura falla, o excede el timeout → retorna `nil`
    /// (la canción se guarda igual como descargada, con duración de fallback).
    func extractMetadata(from url: URL) async -> SongMetadata? {
        do {
            return try await Self.withTimeout(Self.timeout) {
                try await Self.parse(from: url)
            }
        } catch {
            Self.logger.warning("Metadata no disponible (\(url.lastPathComponent)): \(String(describing: error))")
            return nil
        }
    }

    // MARK: - Parsing (nonisolated: corre fuera del MainActor)

    private nonisolated static func parse(from url: URL) async throws -> SongMetadata {
        let asset = AVURLAsset(url: url)

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let metadata = try await asset.load(.metadata)

        var title: String?
        var artist: String?
        var album: String?
        var author: String?
        var artwork: Data?

        for item in metadata {
            try Task.checkCancellation()

            if let keyRawValue = item.commonKey?.rawValue {
                switch keyRawValue {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    title = try? await item.load(.stringValue)

                case AVMetadataKey.commonKeyArtist.rawValue:
                    artist = try? await item.load(.stringValue)

                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    album = try? await item.load(.stringValue)

                case AVMetadataKey.commonKeyAuthor.rawValue:
                    author = try? await item.load(.stringValue)

                case AVMetadataKey.commonKeyArtwork.rawValue:
                    if let imageData = try? await item.load(.dataValue) {
                        artwork = imageData
                    }

                default:
                    break
                }
            }

            // Metadatos específicos de formato (iTunes/ID3)
            if let keyString = item.key as? String {
                if keyString == "©ART" && artist == nil {
                    artist = try? await item.load(.stringValue)
                }
                if keyString == "©nam" && title == nil {
                    title = try? await item.load(.stringValue)
                }
                if keyString == "©alb" && album == nil {
                    album = try? await item.load(.stringValue)
                }
                if keyString == "©wrt" && author == nil {
                    author = try? await item.load(.stringValue)
                }
            }
        }

        let finalTitle = title ?? url.deletingPathExtension().lastPathComponent
        let finalArtist = artist ?? "Artista Desconocido"
        let finalAlbum = album ?? "Álbum Desconocido"

        // Downsampling al decodificar: coste independiente de la resolución de la portada.
        var thumbnail: Data?
        var mediumThumbnail: Data?
        if let artworkData = artwork {
            let thumbs = ImageCompressionService.makeThumbnails(from: artworkData)
            thumbnail = thumbs.small
            mediumThumbnail = thumbs.medium
        }

        return SongMetadata(
            title: finalTitle,
            artist: finalArtist,
            album: finalAlbum,
            author: author,
            duration: durationSeconds,
            artwork: artwork,
            artworkThumbnail: thumbnail,
            artworkMediumThumbnail: mediumThumbnail
        )
    }

    // MARK: - Timeout

    private struct TimedOutError: Error {}

    /// Corre `operation` con un límite de tiempo; cancela la operación si expira.
    private nonisolated static func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw TimedOutError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw TimedOutError() }
            return result
        }
    }
}
