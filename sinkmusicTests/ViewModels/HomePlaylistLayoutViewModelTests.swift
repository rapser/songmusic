//
//  HomePlaylistLayoutViewModelTests.swift
//  sinkmusicTests
//
//  Extraído de PlaylistViewModelTests al separar la curaduría de Inicio en su propio VM.
//

import XCTest
@testable import sinkmusic

@MainActor
final class HomePlaylistLayoutViewModelTests: XCTestCase {

    private var sut: HomePlaylistLayoutViewModel!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockHomeLayoutRepo: MockHomePlaylistLayoutRepository!
    private var playlistUseCases: PlaylistUseCases!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockSongRepo = MockSongRepository()
        mockHomeLayoutRepo = MockHomePlaylistLayoutRepository()
        playlistUseCases = PlaylistUseCases(
            playlistRepository: mockPlaylistRepo,
            songRepository: mockSongRepo,
            homePlaylistLayoutRepository: mockHomeLayoutRepo
        )
        sut = HomePlaylistLayoutViewModel(playlistUseCases: playlistUseCases)
    }

    override func tearDown() {
        sut = nil
        playlistUseCases = nil
        mockPlaylistRepo = nil
        mockSongRepo = nil
        mockHomeLayoutRepo = nil
        super.tearDown()
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
