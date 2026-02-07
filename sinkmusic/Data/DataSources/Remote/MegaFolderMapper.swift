//
//  MegaFolderMapper.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//
//  Convierte la respuesta de la API (nodos) en lista de MegaFile de audio.
//

import Foundation

enum MegaFolderMapper {

    private static let audioExtensions = [".m4a", ".mp3", ".mp4", ".aac", ".flac", ".wav", ".ogg"]

    /// Convierte la respuesta de la API en archivos de audio listos para descargar
    static func mapToAudioFiles(
        response: MegaFolderResponse,
        folderKey: Data,
        crypto: MegaCrypto
    ) -> [MegaFile] {
        guard let nodes = response.f else { return [] }

        var files: [MegaFile] = []
        for node in nodes {
            guard node.t == 0,
                  let encryptedAttrs = node.a,
                  let keyString = node.k,
                  let fileKey = crypto.parseNodeKey(keyString, folderKey: folderKey),
                  let attrs = crypto.decryptAttributes(encryptedAttrs, key: fileKey),
                  let fileName = attrs["n"] as? String,
                  isAudioFileName(fileName) else {
                continue
            }

            files.append(MegaFile(
                id: node.h,
                name: fileName,
                size: node.s,
                decryptionKey: fileKey.base64EncodedString(),
                parentId: node.p
            ))
        }

        return files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func isAudioFileName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return audioExtensions.contains { lower.hasSuffix($0) }
    }
}
