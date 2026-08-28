//
//  DownloadFileStoreProtocol.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Localiza en disco el archivo de audio descargado de una canción.
///
/// Antes esta lógica (`Documents/Music/<uuid>.m4a` + `fileExists`) estaba duplicada como
/// computed property en la entidad `Song` y en `SongDTO` — I/O de FileManager dentro de
/// tipos que deberían ser puros. Ahora es un servicio inyectable.
protocol DownloadFileStoreProtocol: Sendable {

    /// Ruta donde vive (o viviría) el archivo local de la canción, exista o no.
    func fileURL(for songID: UUID) -> URL

    /// Ruta del archivo local solo si existe en disco.
    func existingFileURL(for songID: UUID) -> URL?
}
