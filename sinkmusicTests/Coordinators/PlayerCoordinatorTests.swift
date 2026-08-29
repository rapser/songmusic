//
//  PlayerCoordinatorTests.swift
//  sinkmusicTests
//

import XCTest
import UIKit
@testable import sinkmusic

@MainActor
final class PlayerCoordinatorTests: XCTestCase {

    private var sut: PlayerCoordinator!
    private var metadataVM: MetadataCacheViewModel!
    private var mockLibraryVM: LibraryViewModel!
    private var mockSongRepo: MockSongRepository!
    private var mockReadStore: MockLibraryReadStore!

    override func setUp() {
        super.setUp()
        metadataVM = MetadataCacheViewModel()
        mockSongRepo = MockSongRepository()
        mockReadStore = MockLibraryReadStore()
        let libraryUseCases = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: MockCloudStorageRepository(),
            credentialsRepository: MockCredentialsRepository(),
            playlistRepository: MockPlaylistRepository()
        )
        mockLibraryVM = LibraryViewModel(
            libraryUseCases: libraryUseCases,
            readStore: mockReadStore
        )
        sut = PlayerCoordinator(metadataViewModel: metadataVM)
    }

    override func tearDown() {
        sut = nil
        metadataVM = nil
        mockLibraryVM = nil
        mockSongRepo = nil
        mockReadStore = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_currentSongIsNil() {
        XCTAssertNil(sut.currentSong)
    }

    // MARK: - onLibrarySongsChanged

    func test_onLibrarySongsChanged_withNoPlayingID_doesNotSetCurrentSong() {
        let songs = [Song.make(title: "A"), Song.make(title: "B")].map(SongMapper.toUI)

        sut.onLibrarySongsChanged(songs, currentlyPlayingID: nil)

        XCTAssertNil(sut.currentSong)
    }

    func test_onLibrarySongsChanged_withMatchingPlayingID_setsCurrentSong() {
        let song = Song.make(title: "Playing Now")
        let songUI = SongMapper.toUI(song)

        sut.onLibrarySongsChanged([songUI], currentlyPlayingID: song.id)

        XCTAssertEqual(sut.currentSong?.title, "Playing Now")
    }

    func test_onLibrarySongsChanged_withNonMatchingPlayingID_doesNotSetCurrentSong() {
        let songs = [Song.make(title: "A"), Song.make(title: "B")].map(SongMapper.toUI)

        sut.onLibrarySongsChanged(songs, currentlyPlayingID: UUID())

        XCTAssertNil(sut.currentSong)
    }

    func test_onLibrarySongsChanged_updatesCurrentSong_whenPlayingSongChanges() {
        let songID = UUID()
        let original = SongMapper.toUI(Song.make(id: songID, title: "Original"))
        sut.onLibrarySongsChanged([original], currentlyPlayingID: songID)
        XCTAssertEqual(sut.currentSong?.title, "Original")

        let updated = SongMapper.toUI(Song.make(id: songID, title: "Updated"))
        sut.onLibrarySongsChanged([updated], currentlyPlayingID: songID)

        XCTAssertEqual(sut.currentSong?.title, "Updated")
    }

    // MARK: - onPlayingIDChanged

    func test_onPlayingIDChanged_nil_clearsCurrentSong() async {
        let song = SongMapper.toUI(Song.make(title: "Was Playing"))
        sut.onLibrarySongsChanged([song], currentlyPlayingID: song.id)
        XCTAssertNotNil(sut.currentSong)

        await sut.onPlayingIDChanged(nil, libraryViewModel: mockLibraryVM)

        XCTAssertNil(sut.currentSong)
    }

    func test_onPlayingIDChanged_nil_clearsMetadataCache() async {
        let song = SongMapper.toUI(Song.make(title: "Was Playing"))
        sut.onLibrarySongsChanged([song], currentlyPlayingID: song.id)

        await sut.onPlayingIDChanged(nil, libraryViewModel: mockLibraryVM)

        XCTAssertNil(metadataVM.cachedArtwork)
        XCTAssertNil(metadataVM.cachedThumbnail)
    }

    func test_onPlayingIDChanged_knownSong_setsCurrentSong() async {
        let song = Song.make(title: "Selected")
        let songUI = SongMapper.toUI(song)
        sut.onLibrarySongsChanged([songUI], currentlyPlayingID: nil)

        await sut.onPlayingIDChanged(song.id, libraryViewModel: mockLibraryVM)

        XCTAssertEqual(sut.currentSong?.id, song.id)
        XCTAssertEqual(sut.currentSong?.title, "Selected")
    }

    func test_onPlayingIDChanged_unknownSong_doesNotSetCurrentSong() async {
        await sut.onPlayingIDChanged(UUID(), libraryViewModel: mockLibraryVM)

        XCTAssertNil(sut.currentSong)
    }

    func test_onPlayingIDChanged_unknownSong_doesNotClearExistingCurrentSong() async {
        let song = SongMapper.toUI(Song.make(title: "Current"))
        sut.onLibrarySongsChanged([song], currentlyPlayingID: song.id)
        XCTAssertNotNil(sut.currentSong)

        await sut.onPlayingIDChanged(UUID(), libraryViewModel: mockLibraryVM)

        XCTAssertNotNil(sut.currentSong, "currentSong should remain unchanged for unknown IDs")
    }

    // MARK: - Carga de artwork (arranque en frío con canción restaurada)

    /// Reproduce el bug reportado: al restaurar la última canción al abrir la app,
    /// `currentlyPlayingID` ya viene fijado antes de que la vista se monte, así que solo
    /// `onLibrarySongsChanged` corre primero (vía `.task`). Si esa llamada por sí sola no
    /// deja el artwork cacheado, el mini reproductor se queda con el placeholder por defecto.
    func test_onLibrarySongsChanged_thenOnPlayingIDChanged_loadsFullArtwork() async {
        let artwork = Self.makeValidImageData()
        let song = Song.make(title: "Restored", artworkData: artwork)
        mockSongRepo.songs = [song]
        let songUI = SongMapper.toUI(song)

        // Simula el .task de MainAppView: primero el lookup síncrono...
        sut.onLibrarySongsChanged([songUI], currentlyPlayingID: song.id)
        XCTAssertNil(metadataVM.cachedArtwork, "Todavía no debería haber artwork tras solo el lookup")

        // ...y ahora el fetch async explícito que faltaba.
        await sut.onPlayingIDChanged(song.id, libraryViewModel: mockLibraryVM)

        XCTAssertNotNil(metadataVM.cachedArtwork, "El artwork completo debe quedar cacheado tras el fetch async")
    }

    /// Llamarlo repetidas veces para la misma canción (p. ej. cada vez que la biblioteca se
    /// refresca) no debe volver a pedir el artwork completo.
    func test_onPlayingIDChanged_calledTwiceForSameSong_fetchesArtworkOnlyOnce() async {
        let song = Song.make(title: "Same Song", artworkData: Data([0x01]))
        mockSongRepo.songs = [song]
        let songUI = SongMapper.toUI(song)
        sut.onLibrarySongsChanged([songUI], currentlyPlayingID: song.id)

        await sut.onPlayingIDChanged(song.id, libraryViewModel: mockLibraryVM)
        await sut.onPlayingIDChanged(song.id, libraryViewModel: mockLibraryVM)

        XCTAssertEqual(mockSongRepo.getByIDCallCount, 1)
    }

    /// Cambiar de canción sí debe volver a cargar el artwork.
    func test_onPlayingIDChanged_differentSong_refetchesArtwork() async {
        let songA = Song.make(title: "A", artworkData: Data([0x01]))
        let songB = Song.make(title: "B", artworkData: Data([0x02]))
        mockSongRepo.songs = [songA, songB]
        sut.onLibrarySongsChanged([songA, songB].map(SongMapper.toUI), currentlyPlayingID: songA.id)

        await sut.onPlayingIDChanged(songA.id, libraryViewModel: mockLibraryVM)
        await sut.onPlayingIDChanged(songB.id, libraryViewModel: mockLibraryVM)

        XCTAssertEqual(mockSongRepo.getByIDCallCount, 2)
    }

    // MARK: - Lookup efficiency (O(1) vs O(n))

    func test_onLibrarySongsChanged_withLargeLibrary_usesLookup() {
        let count = 1000
        let songs = (0..<count).map { SongMapper.toUI(Song.make(title: "Song \($0)")) }
        let target = songs[500]

        sut.onLibrarySongsChanged(songs, currentlyPlayingID: target.id)

        XCTAssertEqual(sut.currentSong?.id, target.id)
    }

    // MARK: - Helpers

    private static func makeValidImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData()!
    }
}
