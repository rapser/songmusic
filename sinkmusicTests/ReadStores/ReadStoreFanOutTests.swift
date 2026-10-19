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
//  La medición original (4 señales por reproducción) justificó sacar `playCount` de
//  `SongDTO` a `SongPlayStatsDTO`. Estos tests fijan el resultado: ahora dar al play
//  despierta **solo a Inicio**, que es la única pantalla que muestra algo derivado del
//  contador.
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

    /// Reproducir una canción escribe en `SongPlayStatsDTO` y en la ventana del ranking,
    /// nunca en `SongDTO`. Solo Inicio muestra algo derivado del contador, así que es la
    /// única que se recarga.
    ///
    /// Cuando el contador vivía en `SongDTO` eran **4 señales**: las cuatro tiendas lo
    /// vigilan, y Biblioteca, Playlists y Búsqueda recargaban enteras sin usar el dato.
    func test_incrementPlayCount_wakesUpOnlyHome() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        let repository = ReadStoreTestSupport.makeSongRepository(context)

        let stores = makeStores(context)
        let counts = try await countSignals(from: stores) {
            try await repository.incrementPlayCount(for: song.id)
        }

        XCTAssertEqual(counts["home"], 1, "Inicio sí: muestra 'lo que más escuchas' y 'recientes'")
        XCTAssertNil(counts["library"], "Biblioteca no muestra el contador")
        XCTAssertNil(counts["search"], "Búsqueda tampoco")
        XCTAssertNil(counts["playlist"], "Playlists tampoco")
        XCTAssertEqual(counts.values.reduce(0, +), 1, "Antes eran 4 señales por reproducción")
    }

    // MARK: - Coalescing

    /// El debounce de 120 ms sí hace su trabajo: una ráfaga de escrituras seguidas produce
    /// una sola señal, no una por escritura.
    func test_burstOfWrites_isCoalescedIntoOneSignal() async throws {
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

        XCTAssertEqual(counts.values.reduce(0, +), 1,
                       "10 reproducciones seguidas siguen siendo 1 señal, no 10")
    }

    /// Lo que sí sigue despertando a las cuatro: cambiar la canción de verdad (su estado de
    /// descarga, su metadata). Eso es correcto —todas muestran canciones— y es la razón de
    /// que mereciera la pena mover solo el contador.
    func test_songWrite_stillWakesUpEveryReadStore() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        let repository = ReadStoreTestSupport.makeSongRepository(context)

        let stores = makeStores(context)
        let counts = try await countSignals(from: stores) {
            try await repository.updateDownloadStatus(for: song.id, isDownloaded: false)
        }

        XCTAssertEqual(counts.values.reduce(0, +), 4)
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
