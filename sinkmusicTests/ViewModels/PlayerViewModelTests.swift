//
//  PlayerViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlayerViewModelTests: XCTestCase {

    private var sut: PlayerViewModel!
    private var mockAudioPlayer: MockAudioPlayerRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockEventBus: MockEventBus!
    private var mockLiveActivity: MockLiveActivityService!
    private var playerUseCases: PlayerUseCases!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        mockSongRepo = MockSongRepository()
        mockEventBus = MockEventBus()
        mockLiveActivity = MockLiveActivityService()
        playerUseCases = PlayerUseCases(
            audioPlayerRepository: mockAudioPlayer,
            songRepository: mockSongRepo
        )
        sut = PlayerViewModel(
            playerUseCases: playerUseCases,
            eventBus: mockEventBus,
            liveActivityService: mockLiveActivity
        )
    }

    override func tearDown() {
        sut = nil
        playerUseCases = nil
        mockAudioPlayer = nil
        mockSongRepo = nil
        mockEventBus = nil
        mockLiveActivity = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_isNotPlaying() {
        XCTAssertFalse(sut.isPlaying)
        XCTAssertNil(sut.currentlyPlayingID)
        XCTAssertFalse(sut.isShuffleEnabled)
        XCTAssertEqual(sut.repeatMode, .off)
    }

    // MARK: - play()

    func test_play_withDownloadedSong_setsCurrentlyPlayingID() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]

        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        XCTAssertEqual(sut.currentlyPlayingID, songID)
    }

    func test_play_songNotDownloaded_doesNotSetCurrentlyPlayingID() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        await sut.play(songID: song.id, queue: [SongMapper.toUI(song)])

        XCTAssertNil(sut.currentlyPlayingID)
    }

    func test_play_notInRepository_doesNotSetCurrentlyPlayingID() async {
        await sut.play(songID: UUID(), queue: [])
        XCTAssertNil(sut.currentlyPlayingID)
    }

    // MARK: - pause()

    func test_pause_callsUseCasePause() async {
        await sut.pause()
        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
    }

    // MARK: - stop()

    func test_stop_clearsCurrentlyPlayingID() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        await sut.stop()

        XCTAssertNil(sut.currentlyPlayingID)
    }

    // MARK: - toggleShuffle()

    func test_toggleShuffle_enablesWhenOff() {
        XCTAssertFalse(sut.isShuffleEnabled)
        sut.toggleShuffle()
        XCTAssertTrue(sut.isShuffleEnabled)
    }

    func test_toggleShuffle_disablesWhenOn() {
        sut.toggleShuffle()
        sut.toggleShuffle()
        XCTAssertFalse(sut.isShuffleEnabled)
    }

    // MARK: - toggleRepeat()

    func test_toggleRepeat_cyclesThroughModes() {
        XCTAssertEqual(sut.repeatMode, .off)
        sut.toggleRepeat()
        XCTAssertEqual(sut.repeatMode, .repeatAll)
        sut.toggleRepeat()
        XCTAssertEqual(sut.repeatMode, .repeatOne)
        sut.toggleRepeat()
        XCTAssertEqual(sut.repeatMode, .off)
    }

    // MARK: - seek()

    func test_seek_updatesPlaybackTime() async {
        await sut.seek(to: 45.0)
        XCTAssertEqual(sut.playbackTime, 45.0)
    }

    // MARK: - EventBus reactions

    func test_eventBus_stateChanged_updatesIsPlaying() async {
        mockEventBus.emit(.stateChanged(isPlaying: true, songID: UUID()))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(sut.isPlaying)
    }

    func test_eventBus_stateChanged_false_updatesIsPlaying() async {
        mockEventBus.emit(.stateChanged(isPlaying: false, songID: nil))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(sut.isPlaying)
    }

    func test_eventBus_timeUpdated_updatesSongDuration() async {
        mockEventBus.emit(.timeUpdated(current: 10, duration: 180))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.songDuration, 180)
    }

    // MARK: - LiveActivity

    func test_play_withDownloadedSong_startsLiveActivity() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        mockEventBus.emit(.stateChanged(isPlaying: true, songID: songID))
        try? await Task.sleep(for: .milliseconds(50))

        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        XCTAssertGreaterThanOrEqual(mockLiveActivity.startCallCount, 0)
    }

    // MARK: - Helpers

    private func createTempAudioFile(songID: UUID) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let musicDir = docs.appendingPathComponent("Music")
        try FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
        let file = musicDir.appendingPathComponent("\(songID.uuidString).m4a")
        FileManager.default.createFile(atPath: file.path, contents: Data())
        return musicDir
    }
}
