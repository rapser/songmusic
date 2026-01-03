//
//  RepeatMode.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Modos de repetición del reproductor
enum RepeatMode: String, Sendable {
    case off = "off"
    case repeatAll = "repeatAll"
    case repeatOne = "repeatOne"

    /// Siguiente modo en el ciclo
    func next() -> RepeatMode {
        switch self {
        case .off:
            return .repeatAll
        case .repeatAll:
            return .repeatOne
        case .repeatOne:
            return .off
        }
    }

    /// Descripción legible
    var description: String {
        switch self {
        case .off:
            return "Sin repetición"
        case .repeatAll:
            return "Repetir todo"
        case .repeatOne:
            return "Repetir canción"
        }
    }

    /// Nombre del ícono SF Symbol
    var iconName: String {
        switch self {
        case .off:
            return "repeat"
        case .repeatAll:
            return "repeat"
        case .repeatOne:
            return "repeat.1"
        }
    }
}
