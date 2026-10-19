//
//  HomeReadStoreTests.swift
//  sinkmusicTests
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class HomeReadStoreTests: XCTestCase {

    private func makeSUT(
        _ context: ModelContext,
        ranking: RankingWindowRepositoryProtocol? = nil
    ) -> HomeReadStore {
        HomeReadStore(
            libraryUseCases: ReadStoreTestSupport.makeLibraryUseCases(context, ranking: ranking),
            playlistUseCases: ReadStoreTestSupport.makePlaylistUseCases(context),
            homeLayoutUseCases: ReadStoreTestSupport.makeHomeLayoutUseCases(context),
            modelContext: context
        )
    }

    func test_recentlyPlayedSongs_ordersByLastPlayedDescending() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Old", isDownloaded: true, lastPlayedAt: Date(timeIntervalSinceNow: -300))
        try ReadStoreTestSupport.insertSong(context, title: "New", isDownloaded: true, lastPlayedAt: Date(timeIntervalSinceNow: -10))
        try ReadStoreTestSupport.insertSong(context, title: "Never", lastPlayedAt: nil)

        let sut = makeSUT(context)
        let songs = try await sut.recentlyPlayedSongs(limit: 10)

        XCTAssertEqual(songs.count, 2)
        XCTAssertEqual(songs.first?.title, "New")
    }

    func test_recentlyPlayedSongs_excludesRemovedDownloads() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "StillDownloaded", isDownloaded: true, lastPlayedAt: Date())
        try ReadStoreTestSupport.insertSong(context, title: "RemovedDownload", isDownloaded: false, lastPlayedAt: Date())

        let sut = makeSUT(context)
        let songs = try await sut.recentlyPlayedSongs(limit: 10)

        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs.first?.title, "StillDownloaded")
    }

    func test_mostPlayedSongs_excludesRemovedDownloads() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        let still = try ReadStoreTestSupport.insertSong(context, title: "StillDownloaded", isDownloaded: true)
        let removed = try ReadStoreTestSupport.insertSong(context, title: "RemovedDownload", isDownloaded: false)
        // Ambas con reproducciones recientes; solo la descargada debe salir en el ranking.
        for _ in 0..<5 { await ranking.registerPlay(songID: still.id) }
        for _ in 0..<9 { await ranking.registerPlay(songID: removed.id) }

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["StillDownloaded"])
    }

    func test_mostPlayedSongs_ordersByWindowedPlayCount() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        let a = try ReadStoreTestSupport.insertSong(context, title: "A", isDownloaded: true)
        let b = try ReadStoreTestSupport.insertSong(context, title: "B", isDownloaded: true)
        let c = try ReadStoreTestSupport.insertSong(context, title: "C", isDownloaded: true)
        for _ in 0..<2 { await ranking.registerPlay(songID: a.id) }
        for _ in 0..<5 { await ranking.registerPlay(songID: b.id) }
        // c nunca se reprodujo → no aparece en el ranking.
        _ = c

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["B", "A"])
    }

    // MARK: - Ranking sin ventana activa

    /// Una semana sin escuchar nada caducaba todas las ventanas y la sección de Inicio se
    /// quedaba en blanco. Ahora cae al `playCount` histórico.
    func test_mostPlayedSongs_withoutActiveWindow_fallsBackToHistoricPlayCount() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        try ReadStoreTestSupport.insertSong(context, title: "Pocas", isDownloaded: true, playCount: 3)
        try ReadStoreTestSupport.insertSong(context, title: "Muchas", isDownloaded: true, playCount: 40)
        try ReadStoreTestSupport.insertSong(context, title: "Medias", isDownloaded: true, playCount: 12)
        // Nadie registró reproducciones en la ventana: `activeCounts()` viene vacío.

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["Muchas", "Medias", "Pocas"])
    }

    /// Mientras haya ventana viva manda ella, aunque el histórico diga otra cosa.
    func test_mostPlayedSongs_activeWindowTakesPrecedenceOverHistoric() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)
        let veteran = try ReadStoreTestSupport.insertSong(context, title: "Veterana", isDownloaded: true, playCount: 500)
        let fresh = try ReadStoreTestSupport.insertSong(context, title: "Reciente", isDownloaded: true, playCount: 2)
        await ranking.registerPlay(songID: fresh.id)
        _ = veteran

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["Reciente"])
    }

    /// Biblioteca nueva: sin ventana y sin histórico la sección sí debe salir vacía, no
    /// listar toda la biblioteca por orden alfabético bajo "lo que más escuchas".
    func test_mostPlayedSongs_neverPlayed_staysEmpty() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "A", isDownloaded: true, playCount: 0)
        try ReadStoreTestSupport.insertSong(context, title: "B", isDownloaded: true, playCount: 0)

        let sut = makeSUT(context)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertTrue(songs.isEmpty)
    }

    /// Las entradas de la ventana sobreviven a que se quite la descarga (`updateDownloadStatus`
    /// no las toca), así que `activeCounts()` puede venir lleno y aun así no haber nada que
    /// mostrar. El respaldo se decide sobre el resultado, no sobre si `counts` está vacío.
    func test_mostPlayedSongs_windowOnlyHasUndownloadedSongs_fallsBackToHistoric() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let ranking = ReadStoreTestSupport.makeRankingWindowRepository(context)

        // Se escuchó y después se le quitó la descarga: su ventana sigue viva.
        let removed = try ReadStoreTestSupport.insertSong(context, title: "SinDescarga", isDownloaded: false, playCount: 9)
        await ranking.registerPlay(songID: removed.id)

        // Esta sí está en disco y tiene histórico, pero ninguna ventana.
        try ReadStoreTestSupport.insertSong(context, title: "Descargada", isDownloaded: true, playCount: 4)

        let sut = makeSUT(context, ranking: ranking)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["Descargada"])
    }

    func test_mostPlayedSongs_historicFallback_excludesRemovedDownloads() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, title: "Descargada", isDownloaded: true, playCount: 5)
        try ReadStoreTestSupport.insertSong(context, title: "SinDescarga", isDownloaded: false, playCount: 99)

        let sut = makeSUT(context)
        let songs = try await sut.mostPlayedSongs(limit: 10)

        XCTAssertEqual(songs.map(\.title), ["Descargada"])
    }

    func test_mostPlayedSongs_historicFallback_respectsLimit() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        for index in 0..<8 {
            try ReadStoreTestSupport.insertSong(context, title: "S\(index)", isDownloaded: true, playCount: index + 1)
        }

        let sut = makeSUT(context)
        let songs = try await sut.mostPlayedSongs(limit: 3)

        XCTAssertEqual(songs.map(\.title), ["S7", "S6", "S5"])
    }

    func test_downloadedSongs_returnsOnlyDownloaded() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertSong(context, isDownloaded: true)
        try ReadStoreTestSupport.insertSong(context, isDownloaded: false)

        let sut = makeSUT(context)
        let songs = try await sut.downloadedSongs()

        XCTAssertEqual(songs.count, 1)
    }

    func test_playlists_returnsInsertedPlaylists() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try ReadStoreTestSupport.insertPlaylist(context, name: "Rock")
        try ReadStoreTestSupport.insertPlaylist(context, name: "Jazz")

        let sut = makeSUT(context)
        let playlists = try await sut.playlists()

        XCTAssertEqual(playlists.count, 2)
    }

    func test_changes_emitsSignal_whenPlaylistInserted() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let sut = makeSUT(context)

        // Suscribirse ANTES de disparar el cambio: `changes()` registra la continuación de
        // forma síncrona y el `AsyncStream` bufferiza, así que la señal no se pierde aunque
        // el `Task` aún no haya empezado a iterar. Evita la carrera de los `Task.sleep`.
        let stream = sut.changes()
        let emitted = expectation(description: "changes() emite al insertar una playlist")
        let task = Task {
            for await _ in stream {
                emitted.fulfill()
                break
            }
        }

        try ReadStoreTestSupport.insertPlaylist(context)

        await fulfillment(of: [emitted], timeout: 2.0)
        task.cancel()
    }
}
