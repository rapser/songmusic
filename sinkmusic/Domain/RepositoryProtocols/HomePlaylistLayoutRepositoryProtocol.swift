//
//  HomePlaylistLayoutRepositoryProtocol.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Protocolo de repositorio para la curaduría de playlists en Inicio: cuáles se muestran,
/// en qué orden, y en qué orden quedan las que no se muestran ("Otros").
protocol HomePlaylistLayoutRepositoryProtocol: Sendable {

    /// Orden completo guardado (Inicio primero, luego Otros) y cuántas de esas, desde el
    /// principio, pertenecen a Inicio. `nil` si el usuario nunca lo personalizó.
    func load() -> (order: [UUID], homeCount: Int)?

    /// Guarda el orden completo y el corte de Inicio.
    func save(order: [UUID], homeCount: Int)
}
