//
//  SearchFilter.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Filtros de búsqueda disponibles
enum SearchFilter: String, CaseIterable, Sendable {
    case all = "Todo"
    case song = "Canción"
    case artist = "Artista"
    case album = "Álbum"

    /// Ícono SF Symbol para el filtro
    var iconName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .song:
            return "music.note"
        case .artist:
            return "person.fill"
        case .album:
            return "square.stack"
        }
    }
}
