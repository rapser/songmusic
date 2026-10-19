//
//  HomePlaylistLayoutUseCasesTests.swift
//  sinkmusicTests
//
//  Estaban dentro de `PlaylistUseCasesTests`, que montaba el repositorio de la curaduría
//  para todos sus tests aunque solo lo usaran estos.
//

import XCTest
@testable import sinkmusic

@MainActor
final class HomePlaylistLayoutUseCasesTests: XCTestCase {

    private var sut: HomePlaylistLayoutUseCases!
    private var mockPlaylistRepo: MockPlaylistRepository!
    private var mockHomeLayoutRepo: MockHomePlaylistLayoutRepository!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockHomeLayoutRepo = MockHomePlaylistLayoutRepository()
        sut = HomePlaylistLayoutUseCases(
            playlistRepository: mockPlaylistRepo,
            homePlaylistLayoutRepository: mockHomeLayoutRepo
        )
    }

    override func tearDown() {
        sut = nil
        mockPlaylistRepo = nil
        mockHomeLayoutRepo = nil
        super.tearDown()
    }

    // MARK: - getHomePlaylistLayout()

    func test_getHomePlaylistLayout_withNoSavedPreference_defaultsToFirstFour() async throws {
        let playlists = (0..<6).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists

        let layout = try await sut.getHomePlaylistLayout()

        XCTAssertEqual(layout.shown.map(\.id), playlists.prefix(4).map(\.id))
        XCTAssertEqual(layout.others.map(\.id), playlists.suffix(2).map(\.id))
    }

    func test_getHomePlaylistLayout_withSavedPreference_respectsOrderAndCut() async throws {
        let playlists = (0..<4).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        // Orden inverso, solo 2 en Inicio
        mockHomeLayoutRepo.stateToLoad = (
            [playlists[3].id, playlists[2].id, playlists[1].id, playlists[0].id],
            2
        )

        let layout = try await sut.getHomePlaylistLayout()

        XCTAssertEqual(layout.shown.map(\.id), [playlists[3].id, playlists[2].id])
        XCTAssertEqual(layout.others.map(\.id), [playlists[1].id, playlists[0].id])
    }

    func test_getHomePlaylistLayout_newPlaylistNotInSavedOrder_goesToOthers() async throws {
        let existing = Playlist.make(name: "Existing")
        let brandNew = Playlist.make(name: "Brand New")
        mockPlaylistRepo.playlists = [existing, brandNew]
        mockHomeLayoutRepo.stateToLoad = ([existing.id], 1)

        let layout = try await sut.getHomePlaylistLayout()

        XCTAssertEqual(layout.shown.map(\.id), [existing.id])
        XCTAssertEqual(layout.others.map(\.id), [brandNew.id], "Una playlist nueva no debe invadir Inicio sin que el usuario la agregue")
    }

    func test_getHomePlaylistLayout_deletedPlaylistInSavedOrder_isDropped() async throws {
        let stillExists = Playlist.make(name: "Still Exists")
        let deletedID = UUID()
        mockPlaylistRepo.playlists = [stillExists]
        mockHomeLayoutRepo.stateToLoad = ([deletedID, stillExists.id], 2)

        let layout = try await sut.getHomePlaylistLayout()

        XCTAssertEqual(layout.shown.map(\.id), [stillExists.id])
        XCTAssertTrue(layout.others.isEmpty)
    }

    // MARK: - updateHomePlaylistLayout()

    func test_updateHomePlaylistLayout_savesOrderAndHomeCount() async throws {
        let shownIDs = [UUID(), UUID()]
        let otherIDs = [UUID()]

        sut.updateHomePlaylistLayout(shownIDs: shownIDs, otherIDs: otherIDs)

        XCTAssertEqual(mockHomeLayoutRepo.savedOrder, shownIDs + otherIDs)
        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 2)
    }

    /// Defensivo: aunque llegaran más de 4 IDs como "shown" (no debería pasar desde el
    /// ViewModel, que ya lo impide), el UseCase nunca debe persistir más de 4 en Inicio.
    func test_updateHomePlaylistLayout_capsShownIDsAtFour() async throws {
        let shownIDs = (0..<6).map { _ in UUID() }

        sut.updateHomePlaylistLayout(shownIDs: shownIDs, otherIDs: [])

        XCTAssertEqual(mockHomeLayoutRepo.savedHomeCount, 4)
        XCTAssertEqual(mockHomeLayoutRepo.savedOrder?.prefix(4), shownIDs.prefix(4))
        XCTAssertEqual(mockHomeLayoutRepo.savedOrder?.count, 6, "El exceso debe conservarse, corrido a Otros")
    }

    /// Defensivo: si el `homeCount` guardado excediera el máximo (dato corrupto o de una
    /// versión anterior sin el límite), la lectura igual debe respetar el tope de 4.
    func test_getHomePlaylistLayout_capsHomeCountFromCorruptedSavedState() async throws {
        let playlists = (0..<6).map { Playlist.make(name: "P\($0)") }
        mockPlaylistRepo.playlists = playlists
        mockHomeLayoutRepo.stateToLoad = (playlists.map(\.id), 6)

        let layout = try await sut.getHomePlaylistLayout()

        XCTAssertEqual(layout.shown.count, 4)
        XCTAssertEqual(layout.others.count, 2)
    }
}
