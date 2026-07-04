//
//  PlayerCoordinatorTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlayerCoordinatorTests: XCTestCase {

    private var sut: PlayerCoordinator!
    private var metadataVM: MetadataCacheViewModel!
    private var mockLibraryVM: LibraryViewModel!
    private var mockSongRepo: MockSongRepository!
    private var mockEventBus: MockEventBus!

    override func setUp() {
        super.setUp()
        metadataVM = MetadataCacheViewModel()
        mockSongRepo = MockSongRepository()
        mockEventBus = MockEventBus()
        let libraryUseCases = LibraryUseCases(
            songRepository: mockSongRepo,
            cloudStorageRepository: MockCloudStorageRepository(),
            credentialsRepository: MockCredentialsRepository()
        )
        mockLibraryVM = LibraryViewModel(
            libraryUseCases: libraryUseCases,
            eventBus: mockEventBus
        )
        sut = PlayerCoordinator(metadataViewModel: metadataVM)
    }

    override func tearDown() {
        sut = nil
        metadataVM = nil
        mockLibraryVM = nil
        mockSongRepo = nil
        mockEventBus = nil
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

    // MARK: - Lookup efficiency (O(1) vs O(n))

    func test_onLibrarySongsChanged_withLargeLibrary_usesLookup() {
        let count = 1000
        let songs = (0..<count).map { SongMapper.toUI(Song.make(title: "Song \($0)")) }
        let target = songs[500]

        sut.onLibrarySongsChanged(songs, currentlyPlayingID: target.id)

        XCTAssertEqual(sut.currentSong?.id, target.id)
    }
}
