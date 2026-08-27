//
//  PlayerUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class PlayerUseCasesTests: XCTestCase {

    private var sut: PlayerUseCases!
    private var mockAudioPlayer: MockAudioPlayerRepository!
    private var mockSongRepo: MockSongRepository!
    private var mockPlaybackState: MockPlaybackStateRepository!

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        mockSongRepo = MockSongRepository()
        mockPlaybackState = MockPlaybackStateRepository()
        sut = PlayerUseCases(
            audioPlayerRepository: mockAudioPlayer,
            songRepository: mockSongRepo,
            playbackStateRepository: mockPlaybackState
        )
    }

    override func tearDown() {
        sut = nil
        mockAudioPlayer = nil
        mockSongRepo = nil
        mockPlaybackState = nil
        super.tearDown()
    }

    // MARK: - play()

    func test_play_songNotInRepo_throwsSongNotFound() async {
        do {
            try await sut.play(songID: UUID())
            XCTFail("Expected PlayerError.songNotFound")
        } catch PlayerError.songNotFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_play_songNotDownloaded_throwsFileNotDownloaded() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]

        do {
            try await sut.play(songID: song.id)
            XCTFail("Expected PlayerError.fileNotDownloaded")
        } catch PlayerError.fileNotDownloaded {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_play_withValidFile_callsAudioPlayerPlay() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]

        try await sut.play(songID: songID)

        XCTAssertEqual(mockAudioPlayer.playCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastPlayedSongID, songID)
    }

    func test_play_withValidFile_incrementsPlayCount() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]

        try await sut.play(songID: songID)

        XCTAssertEqual(mockSongRepo.incrementPlayCountCallCount, 1)
    }

    func test_play_withValidFile_setsIsPlayingTrue() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]

        try await sut.play(songID: songID)

        let playing = await sut.isPlaying()
        XCTAssertTrue(playing)
        XCTAssertEqual(sut.getCurrentSongID(), songID)
    }

    // MARK: - pause()

    func test_pause_callsAudioPlayerPause() async {
        await sut.pause()
        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
    }

    func test_pause_setsIsPlayingFalse() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        await sut.pause()

        let playing = await sut.isPlaying()
        XCTAssertFalse(playing)
    }

    // MARK: - stop()

    func test_stop_callsAudioPlayerStop() async {
        await sut.stop()
        XCTAssertEqual(mockAudioPlayer.stopCallCount, 1)
    }

    func test_stop_clearsSongState() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        await sut.stop()

        XCTAssertNil(sut.getCurrentSongID())
        let playing = await sut.isPlaying()
        XCTAssertFalse(playing)
    }

    // MARK: - togglePlayPause()

    func test_togglePlayPause_whenPlaying_callsPause() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        try await sut.togglePlayPause()

        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
    }

    func test_togglePlayPause_withNoCurrent_doesNotCallPlay() async throws {
        try await sut.togglePlayPause()
        XCTAssertEqual(mockAudioPlayer.playCallCount, 0)
    }

    // MARK: - seek()

    func test_seek_forwardsToAudioPlayer() async {
        await sut.seek(to: 42.5)
        XCTAssertEqual(mockAudioPlayer.seekCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastSeekTime, 42.5)
    }

    // MARK: - getSongsByIDs()

    func test_getSongsByIDs_returnsOnlyMatchingSongs() async throws {
        let song1 = Song.make(title: "A")
        let song2 = Song.make(title: "B")
        let song3 = Song.make(title: "C")
        mockSongRepo.songs = [song1, song2, song3]

        let result = try await sut.getSongsByIDs([song1.id, song3.id])

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.id == song1.id })
        XCTAssertTrue(result.contains { $0.id == song3.id })
    }

    func test_getSongsByIDs_ignoresUnknownIDs() async throws {
        let song = Song.make()
        mockSongRepo.songs = [song]

        let result = try await sut.getSongsByIDs([song.id, UUID()])

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - getSongByID()

    func test_getSongByID_returnsMatchingSong() async throws {
        let song = Song.make(title: "Bohemian Rhapsody")
        mockSongRepo.songs = [song]

        let result = try await sut.getSongByID(song.id)

        XCTAssertEqual(result?.title, "Bohemian Rhapsody")
    }

    func test_getSongByID_returnsNil_forUnknownID() async throws {
        let result = try await sut.getSongByID(UUID())
        XCTAssertNil(result)
    }

    // MARK: - Now Playing

    func test_play_setsNowPlayingMetadata() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        XCTAssertEqual(mockAudioPlayer.setNowPlayingMetadataCallCount, 1)
    }

    // MARK: - Playback State Persistence

    func test_pendingResumeTime_persistedOnPlay() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]

        try await sut.play(songID: songID)

        XCTAssertEqual(mockPlaybackState.savedTime, 0)
    }

    func test_persistCurrentPlaybackTime_withCurrentSong_savesState() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        sut.persistCurrentPlaybackTime(37.5)

        XCTAssertEqual(mockPlaybackState.savedSongID, songID)
        XCTAssertEqual(mockPlaybackState.savedTime, 37.5)
    }

    func test_persistCurrentPlaybackTime_withNoCurrentSong_doesNotSave() {
        sut.persistCurrentPlaybackTime(37.5)
        XCTAssertEqual(mockPlaybackState.saveCallCount, 0)
    }

    // MARK: - restoreLastPlaybackState()

    func test_restoreLastPlaybackState_withNoSavedState_returnsNil() async {
        let result = await sut.restoreLastPlaybackState()
        XCTAssertNil(result)
    }

    /// Actualización desde una versión anterior: no hay estado guardado en UserDefaults.
    /// Debe ser un no-op limpio, sin borrar nada ni dejar el reproductor en un estado raro.
    func test_restoreLastPlaybackState_onUpgradeFromOldVersion_isCleanNoOp() async {
        // Sin `stateToLoad`: simula UserDefaults sin las claves nuevas.
        let result = await sut.restoreLastPlaybackState()

        XCTAssertNil(result)
        XCTAssertNil(sut.getCurrentSongID())
        XCTAssertEqual(mockPlaybackState.clearCallCount, 0, "No debe borrar nada si no había estado")
        XCTAssertEqual(mockSongRepo.deleteCallCount, 0)
    }

    func test_restoreLastPlaybackState_withDownloadedSong_returnsSongAndTime() async {
        let song = Song.make(isDownloaded: true)
        mockSongRepo.songs = [song]
        mockPlaybackState.stateToLoad = (song.id, 145)

        let result = await sut.restoreLastPlaybackState()

        XCTAssertEqual(result?.song.id, song.id)
        XCTAssertEqual(result?.time, 145)
        let playing = await sut.isPlaying()
        XCTAssertFalse(playing)
        XCTAssertEqual(sut.getCurrentSongID(), song.id)
    }

    func test_restoreLastPlaybackState_withNoLongerDownloadedSong_clearsAndReturnsNil() async {
        let song = Song.make(isDownloaded: false)
        mockSongRepo.songs = [song]
        mockPlaybackState.stateToLoad = (song.id, 145)

        let result = await sut.restoreLastPlaybackState()

        XCTAssertNil(result)
        XCTAssertEqual(mockPlaybackState.clearCallCount, 1)
    }

    func test_togglePlayPause_afterRestore_resumesFromSavedTime() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        mockPlaybackState.stateToLoad = (songID, 145)
        _ = await sut.restoreLastPlaybackState()

        try await sut.togglePlayPause()

        // La posición viaja como parámetro de `play`, no con un seek posterior.
        XCTAssertEqual(mockAudioPlayer.lastStartTime, 145)
        XCTAssertEqual(mockAudioPlayer.seekCallCount, 0)
        let playing = await sut.isPlaying()
        XCTAssertTrue(playing)
    }

    // MARK: - resume()

    func test_resume_whenEngineHasTrack_doesNotReplayNorIncrementPlayCount() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)
        await sut.pause()

        let playsBefore = mockAudioPlayer.playCallCount
        let countBefore = mockSongRepo.incrementPlayCountCallCount

        try await sut.resume()

        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.playCallCount, playsBefore, "Reanudar no debe recargar la canción")
        XCTAssertEqual(mockSongRepo.incrementPlayCountCallCount, countBefore, "Reanudar no debe contar otra reproducción")
    }

    func test_resume_afterColdRestore_playsFromSavedTime() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        mockPlaybackState.stateToLoad = (songID, 145)
        _ = await sut.restoreLastPlaybackState()

        // Arranque en frío: el motor no tiene nada cargado.
        mockAudioPlayer.canResumeValue = false

        try await sut.resume()

        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.playCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.lastStartTime, 145)
        XCTAssertEqual(mockSongRepo.incrementPlayCountCallCount, 1)
    }

    func test_togglePlayPause_whenEnginePaused_resumesWithoutSeekingToZero() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)
        await sut.pause()

        try await sut.togglePlayPause()

        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.seekCallCount, 0, "Reanudar no debe reiniciar la posición a 0")
    }

    func test_togglePlayPause_whenEnginePlaying_pauses() async throws {
        let songID = UUID()
        let musicDir = try createTempAudioFile(songID: songID)
        defer { try? FileManager.default.removeItem(at: musicDir) }

        mockSongRepo.songs = [Song.make(id: songID, isDownloaded: true)]
        try await sut.play(songID: songID)

        try await sut.togglePlayPause()

        XCTAssertEqual(mockAudioPlayer.pauseCallCount, 1)
        XCTAssertEqual(mockAudioPlayer.resumeCallCount, 0)
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
