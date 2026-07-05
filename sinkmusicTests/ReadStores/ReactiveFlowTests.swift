//
//  ReactiveFlowTests.swift
//  sinkmusicTests
//
//  Tests de extremo a extremo: ReadStore real + ModelContainer en memoria (sin mocks),
//  verificando que la UI se entera de cambios hechos por SwiftData sin recarga manual.
//

import XCTest
import SwiftData
@testable import sinkmusic

@MainActor
final class ReactiveFlowTests: XCTestCase {

    func test_downloadingASong_updatesLibraryViewModelWithoutManualReload() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let songDataSource = ReadStoreTestSupport.makeSongLocalDataSource(context)
        let song = try ReadStoreTestSupport.insertSong(context, isDownloaded: false)

        let libraryUseCases = ReadStoreTestSupport.makeLibraryUseCases(context)
        let readStore = LibraryReadStore(libraryUseCases: libraryUseCases, modelContext: context)
        let viewModel = LibraryViewModel(libraryUseCases: libraryUseCases, readStore: readStore)

        await viewModel.loadSongs()
        XCTAssertEqual(viewModel.songs.first?.isDownloaded, false)

        // Simula que otra pantalla (descarga) marca la canción como descargada.
        try songDataSource.updateDownloadStatus(for: song.id, isDownloaded: true)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.songs.first?.isDownloaded, true)
    }

    func test_deletingASong_updatesLibraryViewModelWithoutManualReload() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let songDataSource = ReadStoreTestSupport.makeSongLocalDataSource(context)
        let song = try ReadStoreTestSupport.insertSong(context)

        let libraryUseCases = ReadStoreTestSupport.makeLibraryUseCases(context)
        let readStore = LibraryReadStore(libraryUseCases: libraryUseCases, modelContext: context)
        let viewModel = LibraryViewModel(libraryUseCases: libraryUseCases, readStore: readStore)

        await viewModel.loadSongs()
        XCTAssertEqual(viewModel.songs.count, 1)

        try songDataSource.delete(song.id)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(viewModel.songs.isEmpty)
    }

    func test_addingSongToPlaylist_updatesPlaylistViewModelWithoutManualReload() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let song = try ReadStoreTestSupport.insertSong(context)
        let playlist = try ReadStoreTestSupport.insertPlaylist(context)

        let playlistUseCases = ReadStoreTestSupport.makePlaylistUseCases(context)
        let readStore = PlaylistReadStore(playlistUseCases: playlistUseCases, modelContext: context)
        let viewModel = PlaylistViewModel(playlistUseCases: playlistUseCases, readStore: readStore)

        await viewModel.loadPlaylists()
        let domainPlaylist = try await playlistUseCases.getPlaylistByID(playlist.id)
        await viewModel.selectPlaylist(PlaylistMapper.toUI(try XCTUnwrap(domainPlaylist)))
        XCTAssertTrue(viewModel.songsInPlaylist.isEmpty)

        // Cambio hecho "desde otra pantalla": agregar la canción directamente vía UseCases.
        try await playlistUseCases.addSongToPlaylist(songID: song.id, playlistID: playlist.id)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.songsInPlaylist.count, 1)
    }

    func test_changeMadeElsewhere_isSeenBySearchViewModelWithoutPolling() async throws {
        let container = try ReadStoreTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let songDataSource = ReadStoreTestSupport.makeSongLocalDataSource(context)
        try ReadStoreTestSupport.insertSong(context, title: "Existing")

        let searchUseCases = ReadStoreTestSupport.makeSearchUseCases(context)
        let readStore = SearchReadStore(searchUseCases: searchUseCases, modelContext: context)
        let viewModel = SearchViewModel(readStore: readStore)

        await viewModel.search()
        XCTAssertEqual(viewModel.searchResults.count, 1)

        // Cambio hecho "en otra pantalla": se inserta una canción directamente vía DataSource,
        // sin que Search haga polling ni el usuario dispare una nueva búsqueda.
        let newSong = SongDTO(title: "New From Elsewhere", artist: "Someone", fileID: UUID().uuidString)
        try songDataSource.create(newSong)
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.searchResults.count, 2)
    }
}
