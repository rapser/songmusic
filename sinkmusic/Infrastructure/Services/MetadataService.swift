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
    private let logger = Logger(subsystem: "com.sinkmusic.app", category: "MetadataService")

    /// Extrae los metadatos de un archivo de audio local.
    /// Si el archivo no es un formato válido o falla la lectura, retorna nil sin propagar error.
    func extractMetadata(from url: URL) async -> SongMetadata? {
        let asset = AVURLAsset(url: url)

        // Cargar duración y metadata; cualquier fallo de formato se ignora y retornamos nil
        let durationSeconds: Double
        let metadata: [AVMetadataItem]
        do {
            let duration = try await asset.load(.duration)
            durationSeconds = CMTimeGetSeconds(duration)
            metadata = try await asset.load(.metadata)
        } catch {
            logger.warning("No se pudo cargar asset (\(url.lastPathComponent)): \(String(describing: error))")
            return nil
        }

        var title: String?
        var artist: String?
        var album: String?
        var author: String?
        var artwork: Data?

        for item in metadata {
            // Intentar con commonKey primero
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
                    // Extraer artwork como Data
                    if let imageData = try? await item.load(.dataValue) {
                        artwork = imageData
                    }

                default:
                    break
                }
            }

            // También buscar en metadatos específicos de formato (iTunes/ID3)
            if let keyString = item.key as? String {
                // iTunes metadata keys
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

        // Si no se encontró título en metadatos, usar nombre del archivo
        let finalTitle = title ?? url.deletingPathExtension().lastPathComponent
        let finalArtist = artist ?? "Artista Desconocido"
        let finalAlbum = album ?? "Álbum Desconocido"

        // Generar thumbnails si hay artwork
        var thumbnail: Data?
        var mediumThumbnail: Data?
        if let artworkData = artwork {
            thumbnail = ImageCompressionService.createThumbnail(from: artworkData)
            mediumThumbnail = ImageCompressionService.createMediumThumbnail(from: artworkData)
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
}
