//
//  LibraryReadStore.swift
//  sinkmusic
//

import Foundation
import SwiftData

/// Implementación reactiva de `LibraryReadStoreProtocol`.
/// Delega los reads a `LibraryUseCases` y añade la señal de `changes()`
/// observando `ModelContext.didSave` filtrado a `SongDTO`.
@MainActor
final class LibraryReadStore: LibraryReadStoreProtocol {

    private let libraryUseCases: LibraryUseCases
    private let observer: ModelContextChangeObserver

    init(libraryUseCases: LibraryUseCases, modelContext: ModelContext) {
        self.libraryUseCases = libraryUseCases
        self.observer = ModelContextChangeObserver(
            modelContext: modelContext,
            relevantEntityNames: ["SongDTO"]
        )
    }

    func allSongs() async throws -> [Song] {
        try await libraryUseCases.getAllSongs()
    }

    func stats() async throws -> LibraryStats {
        try await libraryUseCases.getLibraryStats()
    }

    func changes() -> AsyncStream<Void> {
        observer.stream()
    }
}
