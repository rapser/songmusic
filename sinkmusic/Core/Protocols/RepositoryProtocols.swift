//
//  RepositoryProtocols.swift
//  sinkmusic
//
//  Created by Refactoring - Repository Pattern
//

import Foundation
import SwiftData

/// Protocolo base para repositorios
/// Cumple con Interface Segregation Principle (SOLID)
protocol Repository {
    associatedtype Entity
    
    func fetch() throws -> [Entity]
    func save(_ entity: Entity) throws
    func delete(_ entity: Entity) throws
}

/// Protocolo específico para el repositorio de canciones
protocol SongRepositoryProtocol {
    func fetchAll() throws -> [Song]
    func fetch(by id: UUID) throws -> Song?
    func fetchDownloaded() throws -> [Song]
    func save(_ song: Song) throws
    func update(_ song: Song) throws
    func delete(_ song: Song) throws
}

/// Protocolo específico para el repositorio de playlists
protocol PlaylistRepositoryProtocol {
    func fetchAll() throws -> [Playlist]
    func fetch(by id: UUID) throws -> Playlist?
    func save(_ playlist: Playlist) throws
    func update(_ playlist: Playlist) throws
    func delete(_ playlist: Playlist) throws
    func addSong(_ song: Song, to playlist: Playlist) throws
    func removeSong(_ song: Song, from playlist: Playlist) throws
}
