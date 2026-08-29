//
//  MegaCryptoTests.swift
//  sinkmusicTests
//
//  Verifica el desencriptado AES-128-CTR de Mega tras reescribirlo con CommonCrypto
//  (antes era un bucle en Swift bloque-a-bloque). Un modo/endianness mal = audio corrupto,
//  así que aquí hay un known-answer test (NIST SP 800-38A F.5.1) además de round-trips.
//

import XCTest
@testable import sinkmusic

final class MegaCryptoTests: XCTestCase {

    private let sut = MegaCrypto()

    private func hex(_ string: String) -> Data {
        var data = Data(capacity: string.count / 2)
        var index = string.startIndex
        while index < string.endIndex {
            let next = string.index(index, offsetBy: 2)
            data.append(UInt8(string[index..<next], radix: 16)!)
            index = next
        }
        return data
    }

    // MARK: - Known Answer Test (NIST SP 800-38A F.5.1 — CTR-AES128, contador big-endian)

    func test_decryptAESCTR_matchesNISTVector() {
        let key = hex("2b7e151628aed2a6abf7158809cf4f3c")
        let counter = hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
        let plaintext = hex(
            "6bc1bee22e409f96e93d7e117393172a" +
            "ae2d8a571e03ac9c9eb76fac45af8e51" +
            "30c81c46a35ce411e5fbc1191a0a52ef" +
            "f69f2445df4f9b17ad2b417be66c3710"
        )
        let ciphertext = hex(
            "874d6191b620e3261bef6864990db6ce" +
            "9806f66b7970fdff8617187bb9fffdff" +
            "5ae4df3edbd5d35e5b4f09020db03eab" +
            "1e031dda2fbe03d1792170a0f3009cee"
        )

        // CTR: la misma operación cifra y descifra.
        XCTAssertEqual(sut.decryptAESCTR(data: plaintext, key: key, nonce: counter), ciphertext)
        XCTAssertEqual(sut.decryptAESCTR(data: ciphertext, key: key, nonce: counter), plaintext)
    }

    func test_decryptAESCTR_roundTrips_largeBuffer() {
        let key = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let nonce = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let original = Data((0..<(3 * 1024 * 1024 + 7)).map { _ in UInt8.random(in: .min ... .max) })

        let encrypted = try XCTUnwrap(sut.decryptAESCTR(data: original, key: key, nonce: nonce))
        XCTAssertNotEqual(encrypted, original)
        let decrypted = try XCTUnwrap(sut.decryptAESCTR(data: encrypted, key: key, nonce: nonce))
        XCTAssertEqual(decrypted, original)
    }

    func test_decryptAESCTR_rejectsBadSizes() {
        XCTAssertNil(sut.decryptAESCTR(data: Data([1, 2, 3]), key: Data(count: 8), nonce: Data(count: 16)))
        XCTAssertNil(sut.decryptAESCTR(data: Data([1, 2, 3]), key: Data(count: 16), nonce: Data(count: 8)))
        XCTAssertEqual(sut.decryptAESCTR(data: Data(), key: Data(count: 16), nonce: Data(count: 16)), Data())
    }

    // MARK: - Streaming file → file

    func test_decryptFile_streaming_matchesInMemory() throws {
        // fileKey de 32 bytes: bytes 0-15 y 16-31 se pliegan con XOR para dar la clave AES;
        // bytes 16-23 son el nonce (extendido a 16 con ceros).
        let fileKey = Data((0..<32).map { UInt8($0 &* 7 &+ 1) })
        let aesKey = sut.deriveAESKey(from: fileKey)
        var counter = Data(count: 16)
        for i in 0..<8 { counter[i] = fileKey[16 + i] }

        let clear = Data((0..<(512 * 1024 + 123)).map { _ in UInt8.random(in: .min ... .max) })
        let encrypted = try XCTUnwrap(sut.decryptAESCTR(data: clear, key: aesKey, nonce: counter))

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let encURL = dir.appendingPathComponent("in.enc")
        let outURL = dir.appendingPathComponent("out.m4a")
        try encrypted.write(to: encURL)

        try sut.decryptFile(at: encURL, to: outURL, fileKey: fileKey)

        XCTAssertEqual(try Data(contentsOf: outURL), clear)
    }

    func test_decryptFile_rejectsShortKey() {
        let dir = FileManager.default.temporaryDirectory
        XCTAssertThrowsError(
            try sut.decryptFile(
                at: dir.appendingPathComponent("nope.enc"),
                to: dir.appendingPathComponent("nope.out"),
                fileKey: Data(count: 8)
            )
        )
    }
}
