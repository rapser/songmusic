//
//  LibraryReadStoreProtocol.swift
//  sinkmusic
//

import Foundation

/// Read-side reactivo para la biblioteca.
/// SOLID: Interface Segregation — expone solo lo que LibraryViewModel consume para lectura.
/// Las mutaciones (borrar, sincronizar, etc.) siguen yendo por LibraryUseCases.
@MainActor
protocol LibraryReadStoreProtocol: AnyObject {
    func allSongs() async throws -> [Song]
    func stats() async throws -> LibraryStats

    /// Emite cada vez que cambia una canción (alta, baja, edición).
    func changes() -> AsyncStream<Void>
}
