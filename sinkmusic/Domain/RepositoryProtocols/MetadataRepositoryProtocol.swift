//
//  MetadataRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para extracción de metadata
/// Abstrae MetadataService de la capa de dominio
protocol MetadataRepositoryProtocol: Sendable {

    /// Extrae metadata de un archivo de audio
    func extractMetadata(from url: URL) async -> SongMetadata?
}

/// Estructura de metadata de canción
struct SongMetadata: Sendable {
    let title: String
    let artist: String
    let album: String
    let author: String?
    let duration: TimeInterval
    let artwork: Data?
    let artworkThumbnail: Data?
    let artworkMediumThumbnail: Data?
}
