//
//  PlaylistPlaceholderColors.swift
//  sinkmusic
//
//  Varios colores distintos para placeholders de playlist (sin portada).
//  Por id de playlist: cada una tiene un color estable y se repiten menos.
//

import SwiftUI

enum PlaylistPlaceholderColors {
    private static let count = gradients.count

    /// Gradiente por índice. Para CreatePlaylistView (aún no hay id).
    static func gradient(at index: Int) -> (Color, Color) {
        gradients[abs(index) % count]
    }

    /// Gradiente estable por playlist. Si eligió color al editar (placeholderColorIndex), se usa ese; si no, por id.
    static func gradient(for playlist: PlaylistUI) -> (Color, Color) {
        if let idx = playlist.placeholderColorIndex, idx >= 0, idx < count {
            return gradient(at: idx)
        }
        return gradient(at: abs(playlist.id.hashValue) % count)
    }

    /// Número de colores disponibles (para el selector en editar playlist).
    static var numberOfColors: Int { count }

    private static let gradients: [(Color, Color)] = [
        (Color(hue: 0.0, saturation: 0.65, brightness: 0.55), Color(hue: 0.02, saturation: 0.75, brightness: 0.35)),   // Rojo
        (Color(hue: 0.08, saturation: 0.7, brightness: 0.6), Color(hue: 0.1, saturation: 0.8, brightness: 0.35)),       // Naranja
        (Color(hue: 0.15, saturation: 0.6, brightness: 0.55), Color(hue: 0.17, saturation: 0.75, brightness: 0.32)),   // Amarillo/ámbar
        (Color(hue: 0.35, saturation: 0.55, brightness: 0.5), Color(hue: 0.38, saturation: 0.7, brightness: 0.3)),     // Verde
        (Color(hue: 0.48, saturation: 0.6, brightness: 0.55), Color(hue: 0.5, saturation: 0.75, brightness: 0.32)),    // Turquesa
        (Color(hue: 0.58, saturation: 0.6, brightness: 0.55), Color(hue: 0.6, saturation: 0.75, brightness: 0.33)),    // Azul
        (Color(hue: 0.72, saturation: 0.55, brightness: 0.55), Color(hue: 0.74, saturation: 0.7, brightness: 0.35)),  // Violeta
        (Color(hue: 0.88, saturation: 0.6, brightness: 0.55), Color(hue: 0.9, saturation: 0.75, brightness: 0.33)),     // Magenta
        (Color(hue: 0.55, saturation: 0.5, brightness: 0.5), Color(hue: 0.57, saturation: 0.65, brightness: 0.28)),     // Índigo
        (Color(hue: 0.12, saturation: 0.5, brightness: 0.52), Color(hue: 0.14, saturation: 0.65, brightness: 0.3)),    // Ámbar
        (Color(hue: 0.95, saturation: 0.55, brightness: 0.5), Color(hue: 0.97, saturation: 0.7, brightness: 0.32)),   // Rosa
        (Color(hue: 0.42, saturation: 0.5, brightness: 0.52), Color(hue: 0.44, saturation: 0.65, brightness: 0.3)),   // Verde esmeralda
        (Color(hue: 0.65, saturation: 0.55, brightness: 0.5), Color(hue: 0.67, saturation: 0.7, brightness: 0.3)),    // Azul violeta
        (Color(hue: 0.05, saturation: 0.6, brightness: 0.5), Color(hue: 0.07, saturation: 0.75, brightness: 0.3)),   // Rojo coral
        (Color(hue: 0.22, saturation: 0.55, brightness: 0.52), Color(hue: 0.24, saturation: 0.7, brightness: 0.32)),  // Dorado
    ]
}
