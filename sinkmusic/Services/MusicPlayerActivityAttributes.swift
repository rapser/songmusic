//
//  MusicPlayerActivityAttributes.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import ActivityKit
import Foundation

/// Atributos para la Live Activity del reproductor de música
struct MusicPlayerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Estado dinámico que cambia durante la reproducción
        var songTitle: String
        var artistName: String
        var isPlaying: Bool
        var currentTime: TimeInterval
        var duration: TimeInterval
        var artworkThumbnail: Data? // Thumbnail pequeño (40x40, < 1KB)
    }

    // Datos estáticos que no cambian durante la actividad
    var songID: String
}
