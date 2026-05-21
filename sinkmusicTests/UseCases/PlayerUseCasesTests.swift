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

    override func setUp() {
        super.setUp()
        mockAudioPlayer = MockAudioPlayerRepository()
        mockSongRepo = MockSongRepository()
        sut = PlayerUseCases(
            audioPlayerRepository: mockAudioPlayer,
            songRepository: mockSongRepo
        )
    }

    override func tearDown() {
        sut = nil
        mockAudioPlayer = nil
        mockSongRepo = nil
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

        XCTAssertTrue(sut.getIsPlaying())
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

        XCTAssertFalse(sut.getIsPlaying())
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
        XCTAssertFalse(sut.getIsPlaying())
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
