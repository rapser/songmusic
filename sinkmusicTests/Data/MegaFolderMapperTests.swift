//
//  MegaFolderMapperTests.swift
//  sinkmusicTests
//

import XCTest
import CommonCrypto
@testable import sinkmusic

final class MegaFolderMapperTests: XCTestCase {

    func test_megaFile_supportsMoreAudioExtensions() {
        XCTAssertTrue(MegaFile(
            id: "1",
            name: "Song.flac",
            size: nil,
            decryptionKey: "key",
            parentId: nil
        ).isAudioFile)

        XCTAssertTrue(MegaFile(
            id: "2",
            name: "Song.wav",
            size: nil,
            decryptionKey: "key",
            parentId: nil
        ).isAudioFile)

        XCTAssertTrue(MegaFile(
            id: "3",
            name: "Song.ogg",
            size: nil,
            decryptionKey: "key",
            parentId: nil
        ).isAudioFile)
    }

    func test_cloudFile_supportsMoreAudioExtensions() {
        XCTAssertTrue(CloudFile(
            id: "1",
            name: "Song.flac",
            size: nil,
            mimeType: "audio/flac",
            downloadURL: nil,
            provider: .mega
        ).isAudioFile)

        XCTAssertTrue(CloudFile(
            id: "2",
            name: "Song.wav",
            size: nil,
            mimeType: "audio/wav",
            downloadURL: nil,
            provider: .mega
        ).isAudioFile)

        XCTAssertTrue(CloudFile(
            id: "3",
            name: "Song.ogg",
            size: nil,
            mimeType: "audio/ogg",
            downloadURL: nil,
            provider: .mega
        ).isAudioFile)
    }

    func test_mapToAudioFiles_usesFallbackKeyCandidateWhenFirstFails() {
        let folderKey = Data(repeating: 0x11, count: 16)
        let wrongFileKey = Data(repeating: 0x22, count: 16)
        let correctFileKey = Data(repeating: 0x33, count: 16)

        let wrongEncryptedKey = aesECBEncrypt(plaintext: wrongFileKey, key: folderKey)!
        let correctEncryptedKey = aesECBEncrypt(plaintext: correctFileKey, key: folderKey)!
        let encryptedAttrs = aesCBCEncrypt(
            plaintext: Data(#"MEGA{"n":"Artist - Song.flac"}"#.utf8),
            key: correctFileKey
        )!

        let node = MegaNode(
            h: "node-1",
            p: nil,
            u: nil,
            t: 0,
            a: base64URL(encryptedAttrs),
            k: "user-a:\(base64URL(wrongEncryptedKey))/user-b:\(base64URL(correctEncryptedKey))",
            s: 1_000,
            ts: nil,
            fa: nil
        )
        let response = MegaFolderResponse(f: [node], ok: nil, s: nil, u: nil, sn: nil)

        let files = MegaFolderMapper.mapToAudioFiles(response: response, folderKey: folderKey, crypto: MegaCrypto())

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.name, "Artist - Song.flac")
    }

    private func aesECBEncrypt(plaintext: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256 else { return nil }

        let bufferSize = plaintext.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            plaintext.withUnsafeBytes { plaintextPtr in
                key.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress,
                        key.count,
                        nil,
                        plaintextPtr.baseAddress,
                        plaintext.count,
                        bufferPtr.baseAddress,
                        bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytesEncrypted)
    }

    private func aesCBCEncrypt(plaintext: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256 else { return nil }

        let iv = Data(count: kCCBlockSizeAES128)
        let bufferSize = plaintext.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            plaintext.withUnsafeBytes { plaintextPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(0),
                            keyPtr.baseAddress,
                            key.count,
                            ivPtr.baseAddress,
                            plaintextPtr.baseAddress,
                            plaintext.count,
                            bufferPtr.baseAddress,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytesEncrypted)
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
