//
//  StorageInfo.swift
//  sinkmusic
//
//  Domain Layer - Entity
//

import Foundation

/// Cuánto ocupa la biblioteca. El audio es una estimación (ver `AppDataUseCases`); el
/// artwork, una medida exacta.
struct StorageInfo: Sendable {
    let totalSongs: Int
    let downloadedSongs: Int
    let estimatedAudioSizeMB: Double
    let artworkSizeMB: Double
    let totalSizeMB: Double

    var formattedTotalSize: String { Self.format(totalSizeMB) }

    var formattedAudioSize: String { Self.format(estimatedAudioSizeMB) }

    var formattedArtworkSize: String { String(format: "%.1f MB", artworkSizeMB) }

    /// Pasa a GB al superar los 1024 MB: "1.20 GB" se lee mejor que "1229 MB".
    private static func format(_ sizeMB: Double) -> String {
        sizeMB > 1024
            ? String(format: "%.2f GB", sizeMB / 1024)
            : String(format: "%.0f MB", sizeMB)
    }
}
