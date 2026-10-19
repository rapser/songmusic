//
//  ReadStoreFanOutTests.swift
//  sinkmusicTests
//
//  Mide el fan-out del read-side: cuántas tiendas despierta una sola escritura.
//
//  Hay cuatro `ModelContextChangeObserver` sobre el mismo `ModelContext`, cada uno con su
//  propio debounce, y `SongDTO` lo vigilan los cuatro. El disparador más caliente es
//  `incrementPlayCount` — o sea, **dar al play** —, que despierta a Inicio, Biblioteca,
//  Playlists y Búsqueda enteras aunque ninguna muestre el contador de reproducciones.
//
//  Estos tests no juzgan: fijan el número actual para poder compararlo después. Sacar
//  `playCount` de `SongDTO` a su propia entidad debería llevar el primero de 4 a 0.
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class ReadStoreFanOutTests: XCTestCase {

    /// Las cuatro tiendas montadas sobre un mismo `ModelContext`, como en la app real
    /// (`DIContainer` las crea todas con `requireModelContext()`).
    private struct Stores {
        let home: HomeReadStore
        let library: LibraryReadStore
        let playlist: PlaylistReadStore
        let search: SearchReadStore

        var all: [any ReadStoreSignalling] { [home, library, playlist, search] }
    }

    private func makeStores(_ context: ModelContext) -> Stores {
        Stores(
            home: HomeReadStore(
                libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
                playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
                modelContext: context
            ),
            library: LibraryReadStore(
                libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context),
                modelContext: context
            ),
            playlist: PlaylistReadStore(
                playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
                modelContext: context
            ),
            search: SearchReadStore(
                searchUseCases: ReadStoreTestSupport.makeSearchUseCases(context),
                modelContext: context
            )
        )
    }

    /// Suscribe las cuatro tiendas **antes** de provocar el cambio y devuelve, por nombre,
    /// cuántas señales recibió cada una.
    private func countSignals(
        from stores: Stores,
        settleFor settle: Duration = .milliseconds(400),
        whenChanging change: () async throws -> Void
    ) async rethrows -> [String: Int] {
        let names = ["home", "library", "playlist", "search"]
        let counter = Counter()

        let tasks = zip(names, stores.all).map { name, store in
            let stream = store.changes()
            return Task { @MainActor in
                for await _ in stream { counter.bump(name) }
            }
        }

        try await change()
        try? await Task.sleep(for: settle)

        tasks.forEach { $0.cancel() }
        return counter.counts
    }

    @MainActor
    private final class Counter {
        private(set) var counts: [String: Int] = [:]
        func bump(_ key: String) { counts[key, default: 0] += 1 }
    }

    // MARK: - El camino caliente: dar al play

    /// Reproducir una canción incrementa `playCount` en `SongDTO`, y eso invalida las cuatro
    /// pantallas. Ninguna de ellas muestra el contador: Inicio solo lo usa para ordenar el
    /// ranking, y Biblioteca, Playlists y Búsqueda ni eso.
    func test_incrementPlayCount_wakesUpEveryReadStore() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        let repository = ReadStoreTestSupport.makeSongRepository(context)

        let stores = makeStores(context)
        let counts = try await countSignals(from: stores) {
            try await repository.incrementPlayCount(for: song.id)
        }

        XCTAssertEqual(counts["home"], 1, "Inicio recarga sus 5 secciones")
        XCTAssertEqual(counts["library"], 1, "Biblioteca recarga canciones + stats")
        XCTAssertEqual(counts["search"], 1, "Búsqueda recarga búsqueda + agregaciones + recomendaciones")
        XCTAssertEqual(counts.values.reduce(0, +), 4,
                       "Una sola reproducción despierta a las cuatro tiendas")
    }

    // MARK: - Coalescing

    /// El debounce de 120 ms sí hace su trabajo: una ráfaga de escrituras seguidas produce
    /// una sola señal por tienda, no una por escritura.
    func test_burstOfWrites_isCoalescedIntoOneSignalPerStore() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        let repository = ReadStoreTestSupport.makeSongRepository(context)

        let stores = makeStores(context)
        let counts = try await countSignals(from: stores) {
            for _ in 0..<10 {
                try await repository.incrementPlayCount(for: song.id)
            }
        }

        XCTAssertEqual(counts.values.reduce(0, +), 4,
                       "10 escrituras seguidas siguen siendo 4 señales, no 40")
    }

    // MARK: - Alcance por entidad

    /// El filtro por nombre de entidad sí acota algo: una escritura en `PlaylistDTO` no
    /// despierta a Biblioteca ni a Búsqueda, que solo vigilan `SongDTO`.
    func test_playlistWrite_doesNotWakeLibraryOrSearch() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let playlistUseCases = ReadStoreTestSupport.makePlaylistUseCases(context)

        let stores = makeStores(context)
        let counts = try await countSignals(from: stores) {
            _ = try await playlistUseCases.createPlaylist(name: "Nueva", description: nil, coverImageData: nil)
        }

        XCTAssertEqual(counts["home"], 1)
        XCTAssertEqual(counts["playlist"], 1)
        XCTAssertNil(counts["library"], "Biblioteca solo vigila SongDTO")
        XCTAssertNil(counts["search"], "Búsqueda solo vigila SongDTO")
    }
}

/// Lo único que estos tests necesitan de una tienda: su señal de cambios.
@MainActor
protocol ReadStoreSignalling: AnyObject {
    func changes() -> AsyncStream<Void>
}

extension HomeReadStore: ReadStoreSignalling {}
extension LibraryReadStore: ReadStoreSignalling {}
extension PlaylistReadStore: ReadStoreSignalling {}
extension SearchReadStore: ReadStoreSignalling {}
