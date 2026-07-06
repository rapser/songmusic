//
//  PlaylistReadStoreProtocol.swift
//  sinkmusic
//

import Foundation

/// Read-side reactivo para playlists.
/// SOLID: Interface Segregation — expone solo lo que PlaylistViewModel consume para lectura.
/// Las mutaciones (crear, renombrar, agregar/quitar canciones) siguen yendo por PlaylistUseCases.
@MainActor
protocol PlaylistReadStoreProtocol: AnyObject {
    func allPlaylists() async throws -> [Playlist]
    func songs(inPlaylist id: UUID) async throws -> [Song]
    func stats(forPlaylist id: UUID) async throws -> PlaylistStats

    /// Emite cada vez que cambian playlists o las canciones que contienen.
    func changes() -> AsyncStream<Void>
}
