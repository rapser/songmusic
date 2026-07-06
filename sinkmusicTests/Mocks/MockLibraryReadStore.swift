//
//  MockLibraryReadStore.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockLibraryReadStore: LibraryReadStoreProtocol {

    var songsValue: [Song] = []
    var statsValue: LibraryStats = LibraryStats(
        totalSongs: 0, downloadedSongs: 0, totalDuration: 0, totalPlays: 0, uniqueArtists: 0, uniqueAlbums: 0
    )

    private var continuation: AsyncStream<Void>.Continuation?
    private lazy var stream: AsyncStream<Void> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init() {
        _ = stream
    }

    func allSongs() async throws -> [Song] { songsValue }
    func stats() async throws -> LibraryStats { statsValue }

    func changes() -> AsyncStream<Void> { stream }

    /// Simula que algo relevante cambió, para que el ViewModel bajo test recargue.
    func simulateChange() {
        continuation?.yield(())
    }
}
