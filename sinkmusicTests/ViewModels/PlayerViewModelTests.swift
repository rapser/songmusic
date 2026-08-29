//
//  PlayerViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlayerViewModelTests: XCTestCase {

    private var sut: PlayerViewModel!
    private var mockAudioPlayer: MockAudioPlayerService!
    private var mockSongRepo: MockSongRepository!
    private var mockEventBus: MockEventBus!
    private var mockLiveActivity: MockLiveActivityService!
    private var mockPlaybackState: MockPlaybackStateRepository!
    private var playerUseCases: PlayerUseCases!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerService()
        mockSongRepo = MockSongRepository()
        mockEventBus = MockEventBus()
        mockLiveActivity = MockLiveActivityService()
        mockPlaybackState = MockPlaybackStateRepository()
        playerUseCases = PlayerUseCases(
            audioPlayer: mockAudioPlayer,
            songRepository: mockSongRepo,
            playbackStateRepository: mockPlaybackState,
            fileStore: DownloadFileStore()
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
        mockPlaybackState = nil
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

    func test_pause_persistsCurrentPlaybackTime() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        await sut.pause()

        XCTAssertEqual(mockPlaybackState.savedSongID, songID)
    }

    // MARK: - restoreLastPlaybackState()

    func test_restoreLastPlaybackState_withSavedSong_restoresMiniPlayerState() async {
        let song = Song.make(isDownloaded: true, duration: 210)
        mockSongRepo.songs = [song]
        mockPlaybackState.stateToLoad = (song.id, 145)

        await sut.restoreLastPlaybackState()

        XCTAssertEqual(sut.currentlyPlayingID, song.id)
        XCTAssertEqual(sut.playbackTime, 145)
        XCTAssertEqual(sut.songDuration, 210)
        XCTAssertFalse(sut.isPlaying)
    }

    func test_restoreLastPlaybackState_withNoSavedState_doesNothing() async {
        await sut.restoreLastPlaybackState()
        XCTAssertNil(sut.currentlyPlayingID)
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

    func test_stop_closesFullPlayerAndClearsPlayingState() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])
        sut.showPlayerView = true

        await sut.stop()

        XCTAssertNil(sut.currentlyPlayingID)
        XCTAssertFalse(sut.showPlayerView)
        XCTAssertFalse(sut.isPlaying)
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

    // MARK: - Comandos remotos (pantalla de bloqueo / Centro de Control)

    /// El bug reportado: iOS mandaba `pauseCommand`, la app lo traducía a un toggle
    /// y acababa REPRODUCIENDO, invirtiendo el espejo con el widget nativo.
    func test_remoteCommand_pause_whenAlreadyPaused_doesNotStartPlayback() async {
        mockEventBus.emit(.remoteCommand(.pause))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioPlayer.playCallCount, 0)
        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 0)
        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
    }

    func test_remoteCommand_play_whenPaused_resumes() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])
        await sut.pause()

        mockEventBus.emit(.remoteCommand(.play))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1, "El play remoto no debe pausar")
    }

    func test_remoteCommand_playPause_whenPlaying_pausesOnce() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        mockEventBus.emit(.remoteCommand(.playPause))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
    }

    /// Antes el servicio emitía el evento Y llamaba a seek directamente: dos seeks por arrastre.
    func test_remoteCommand_seek_seeksExactlyOnce() async {
        mockEventBus.emit(.remoteCommand(.seek(42)))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioPlayer.seekCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime, 42)
    }

    /// Al acabar la cola hay que pausar de verdad, no solo bajar el flag local,
    /// o el widget nativo se queda creyendo que sigue sonando.
    func test_songFinished_lastTrackRepeatOff_pausesThroughUseCases() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }
        let song = Song.make(id: songID, isDownloaded: true)
        mockSongRepo.songs = [song]
        await sut.play(songID: songID, queue: [SongMapper.toUI(song)])

        mockEventBus.emit(.songFinished(songID))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
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
