//
//  MockCloudStorageRepository.swift
//  sinkmusicTests
//

import Foundation
@testable import sinkmusic

@MainActor
final class MockCloudStorageRepository: CloudStorageRepositoryProtocol {

    var remoteFiles: [CloudFile] = []
    var downloadedURLs: [UUID: URL] = [:]
    var durations: [URL: TimeInterval] = [:]

    var downloadCallCount = 0
    var deleteDownloadCallCount = 0

    var shouldThrowOnFetch = false
    var shouldThrowOnDownload = false
    var shouldThrowOnDelete = false

    func fetchSongsFromFolder() async throws -> [CloudFile] {
        if shouldThrowOnFetch { throw CloudStorageError.credentialsNotConfigured }
        return remoteFiles
    }

    func download(fileID: String, songID: UUID) async throws -> URL {
        if shouldThrowOnDownload { throw CloudStorageError.downloadFailed(SongError.fileNotFound) }
        downloadCallCount += 1
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(songID.uuidString).m4a")
        downloadedURLs[songID] = url
        return url
    }

    func getDuration(for url: URL) -> TimeInterval? {
        durations[url]
    }

    func deleteDownload(for songID: UUID) throws {
        if shouldThrowOnDelete { throw SongError.fileNotFound }
        deleteDownloadCallCount += 1
        downloadedURLs.removeValue(forKey: songID)
    }

    func localURL(for songID: UUID) -> URL? {
        downloadedURLs[songID]
    }
}
