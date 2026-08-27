//
//  PlaylistViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlaylistViewModelTests: XCTestCase {

    private var sut: PlaylistViewModel!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockReadStore: MockPlaylistReadStore!
    private var mockHomeLayoutRepo: MockHomePlaylistLayoutRepository!
    private var playlistUseCases: PlaylistUseCases!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockSongRepo = MockSongRepository()
        mockReadStore = MockPlaylistReadStore()
        mockHomeLayoutRepo = MockHomePlaylistLayoutRepository()
        playlistUseCases = PlaylistUseCases(
            playlistRepository: mockPlaylistRepo,
            songRepository: mockSongRepo,
            homePlaylistLayoutRepository: mockHomeLayoutRepo
        )
        sut = PlaylistViewModel(playlistUseCases: playlistUseCases, readStore: mockReadStore)
    }

    override func tearDown() {
        sut = nil
        playlistUseCases = nil
        mockPlaylistRepo = nil
        mockSongRepo = nil
        mockReadStore = nil
        mockHomeLayoutRepo = nil
        super.tearDown()
    }

    // MARK: - loadPlaylists()

    func test_loadPlaylists_populatesPlaylistsArray() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Rock"), Playlist.make(name: "Jazz")]

        await sut.loadPlaylists()

        XCTAssertEqual(sut.playlists.count, 2)
    }

    // MARK: - createPlaylist()

    func test_createPlaylist_emptyName_doesNotCallRepository() async {
        do {
            _ = try await sut.createPlaylist(name: "   ", description: nil, coverImageData: nil)
        } catch {
            // PlaylistError.emptyName es el comportamiento esperado
        }

        XCTAssertEqual(mockPlaylistRepo.createCallCount, 0)
    }

    func test_createPlaylist_validName_callsRepositoryAndAddsToList() async throws {
        _ = try await sut.createPlaylist(name: "My Playlist", description: nil, coverImageData: nil)

        XCTAssertEqual(mockPlaylistRepo.createCallCount, 1)
    }

    // MARK: - renamePlaylist()

    func test_renamePlaylist_updatesName() async {
        let playlist = Playlist.make(name: "Old Name")
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        await sut.loadPlaylists()

        await sut.renamePlaylist(playlist.id, newName: "New Name")

        XCTAssertEqual(mockPlaylistRepo.updateCallCount, 1)
        XCTAssertEqual(mockPlaylistRepo.playlists.first?.name, "New Name")
    }

    // MARK: - deletePlaylist()

    func test_deletePlaylist_removesFromList() async {
        let playlist = Playlist.make()
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        await sut.loadPlaylists()

        await sut.deletePlaylist(playlist.id)

        XCTAssertEqual(mockPlaylistRepo.deleteCallCount, 1)
    }

    // MARK: - reorderSongs()

    func test_reorderSongs_optimisticUpdate_appliedImmediately() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        mockReadStore.songsInPlaylistValue = songs
        await sut.loadPlaylists()
        await sut.loadSongsInPlaylist(playlist.id)

        await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([0]), toOffset: 3)

        XCTAssertEqual(mockPlaylistRepo.updateSongsOrderCallCount, 1)
    }

    func test_reorderSongs_producesCorrectOrder() async {
        let songs = (0..<3).map { Song.make(title: "S\($0)") }
        let playlist = Playlist.make(songs: songs)
        mockPlaylistRepo.playlists = [playlist]
        mockReadStore.playlistsValue = [playlist]
        mockReadStore.songsInPlaylistValue = songs
        await sut.loadPlaylists()
        await sut.loadSongsInPlaylist(playlist.id)

        // Mover último elemento al principio
        await sut.reorderSongs(in: playlist.id, fromOffsets: IndexSet([2]), toOffset: 0)

        let order = mockPlaylistRepo.lastUpdatedSongsOrder
        XCTAssertEqual(order?[0], songs[2].id)
        XCTAssertEqual(order?[1], songs[0].id)
        XCTAssertEqual(order?[2], songs[1].id)
    }

    // MARK: - addSongToPlaylist()

    func test_addSongToPlaylist_callsRepository() async {
        let song = Song.make()
        let playlist = Playlist.make()
        mockSongRepo.songs = [song]
        mockPlaylistRepo.playlists = [playlist]

        await sut.addSongToPlaylist(songID: song.id, playlistID: playlist.id)

        XCTAssertEqual(mockPlaylistRepo.addSongCallCount, 1)
    }

    // MARK: - ReadStore reactivity

    func test_readStoreChanges_reloadsPlaylists() async {
        mockReadStore.playlistsValue = [Playlist.make(name: "Initial")]
        await sut.loadPlaylists()
        mockReadStore.playlistsValue = [Playlist.make(name: "A"), Playlist.make(name: "B")]

        mockReadStore.simulateChange()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.playlists.count, 2)
    }

    // MARK: - Home Layout (curaduría de playlists en Inicio)

    func test_loadHomePlaylistLayout_populatesShownAndOthers() async {
        let playlists = (0..<5).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists

        await sut.loadHomePlaylistLayout()

        XCTAssertEqual(sut.homeShownPlaylists.count, 4)
        XCTAssertEqual(sut.homeOtherPlaylists.count, 1)
    }

    /// Reordenar dentro de "Inicio" con el control ≡.
    func test_moveHomePlaylistWithinShown_reorders() async {
        let playlists = (0..<3).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout() // los 3 caben en Inicio

        sut.moveHomePlaylistWithinShown(fromOffsets: IndexSet([0]), toOffset: 3)

        XCTAssertEqual(sut.homeShownPlaylists.map(\.id), [playlists[1].id, playlists[2].id, playlists[0].id])
        XCTAssertEqual(mockHomeLayoutRepo.saveCallCount, 1)
        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 3)
    }

    /// Reordenar dentro de "Otros".
    func test_moveHomePlaylistWithinOthers_reorders() async {
        let playlists = (0..<6).map { Playlist.make(name: "P\($0)") } // 4 en Inicio, 2 en Otros
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout()
        let otherA = sut.homeOtherPlaylists[0]
        let otherB = sut.homeOtherPlaylists[1]

        sut.moveHomePlaylistWithinOthers(fromOffsets: IndexSet([1]), toOffset: 0)

        XCTAssertEqual(sut.homeOtherPlaylists.map(\.id), [otherB.id, otherA.id])
    }

    // MARK: - Cruzar entre secciones (arrastre entre las dos listas)

    func test_movePlaylistToHome_movesFromOthers() async {
        let playlists = (0..<4).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        // 2 en Inicio, 2 en Otros: hay cupo.
        mockHomeLayoutRepo.stateToLoad = (playlists.map(\.id), 2)
        await sut.loadHomePlaylistLayout()
        let toMove = sut.homeOtherPlaylists[0]

        sut.movePlaylistToHome(toMove.id)

        XCTAssertTrue(sut.homeShownPlaylists.contains { $0.id == toMove.id })
        XCTAssertFalse(sut.homeOtherPlaylists.contains { $0.id == toMove.id })
        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 3)
    }

    /// El caso que fallaba en pantalla: Inicio vacío y una sola playlist en Otros.
    func test_movePlaylistToHome_whenShownIsEmpty() async {
        let only = Playlist.make(name: "Rock")
        mockPlaylistRepo.playlists = [only]
        mockHomeLayoutRepo.stateToLoad = ([only.id], 0) // todo en Otros
        await sut.loadHomePlaylistLayout()
        XCTAssertTrue(sut.homeShownPlaylists.isEmpty)

        sut.movePlaylistToHome(only.id)

        XCTAssertEqual(sut.homeShownPlaylists.map(\.id), [only.id])
        XCTAssertTrue(sut.homeOtherPlaylists.isEmpty)
    }

    /// Máximo 4 en Inicio: soltar una 5ª no debe hacer nada.
    func test_movePlaylistToHome_whenAlreadyFull_doesNothing() async {
        let playlists = (0..<5).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout() // 4 en Inicio, 1 en Otros
        let toMove = sut.homeOtherPlaylists[0]
        let saveCallCountBefore = mockHomeLayoutRepo.saveCallCount

        sut.movePlaylistToHome(toMove.id)

        XCTAssertEqual(sut.homeShownPlaylists.count, 4, "No debe superar el máximo de 4")
        XCTAssertTrue(sut.homeOtherPlaylists.contains { $0.id == toMove.id }, "Debe seguir en Otros")
        XCTAssertEqual(mockHomeLayoutRepo.saveCallCount, saveCallCountBefore, "No debe persistir si no hubo cambio")
    }

    /// Soltar una playlist sobre la sección en la que ya está: no debe duplicarla ni persistir.
    func test_movePlaylistToHome_whenAlreadyInHome_doesNothing() async {
        let playlists = (0..<2).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout()
        let already = sut.homeShownPlaylists[0]
        let saveCallCountBefore = mockHomeLayoutRepo.saveCallCount

        sut.movePlaylistToHome(already.id)

        XCTAssertEqual(sut.homeShownPlaylists.filter { $0.id == already.id }.count, 1)
        XCTAssertEqual(mockHomeLayoutRepo.saveCallCount, saveCallCountBefore)
    }

    func test_movePlaylistToOthers_movesFromHome() async {
        let playlists = (0..<2).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout()
        let toMove = sut.homeShownPlaylists[0]

        sut.movePlaylistToOthers(toMove.id)

        XCTAssertFalse(sut.homeShownPlaylists.contains { $0.id == toMove.id })
        XCTAssertTrue(sut.homeOtherPlaylists.contains { $0.id == toMove.id })
        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 1)
    }

    /// Sacar de Inicio no tiene tope: siempre debe permitirse.
    func test_movePlaylistToOthers_withFullHome_stillWorks() async {
        let playlists = (0..<5).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout() // 4 en Inicio
        let toMove = sut.homeShownPlaylists[0]

        sut.movePlaylistToOthers(toMove.id)

        XCTAssertEqual(sut.homeShownPlaylists.count, 3)
        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 3)
    }

    /// ID desconocido: no debe crashear ni mutar nada.
    func test_movePlaylistToHome_withUnknownID_doesNothing() async {
        let playlists = (0..<2).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        await sut.loadHomePlaylistLayout()
        let before = sut.homeShownPlaylists.map(\.id)

        sut.movePlaylistToHome(UUID())

        XCTAssertEqual(sut.homeShownPlaylists.map(\.id), before)
    }
}
