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
import os

enum MegaFolderMapper {

    private static let audioExtensions = [".m4a", ".mp3", ".mp4", ".aac", ".flac", ".wav", ".ogg"]
    private static let logger = Logger(subsystem: "com.rapser.musicaapp", category: "MegaSync")

    /// Convierte la respuesta de la API en archivos de audio listos para descargar.
    ///
    /// Registra en consola (categoría "MegaSync") un resumen de cuántos nodos se descartaron
    /// y por qué — carpetas, fallo de desencriptación o extensión no soportada — para poder
    /// explicar por qué el conteo final difiere del que muestra la app de Mega.
    static func mapToAudioFiles(
        response: MegaFolderResponse,
        folderKey: Data,
        crypto: MegaCrypto
    ) -> [MegaFile] {
        guard let nodes = response.f else {
            logger.warning("Mega: respuesta sin nodos (f == nil)")
            return []
        }

        var files: [MegaFile] = []
        var folderCount = 0
        var unsupportedExtensions: [String] = []
        // Motivo exacto de cada fallo de desencriptación, por nodo, para poder diagnosticar
        // sin adivinar en qué paso del pipeline (falta de campos, clave, atributos o nombre).
        var decryptionFailureReasons: [String] = []

        for node in nodes {
            guard node.t == 0 else {
                folderCount += 1
                continue
            }

            guard let encryptedAttrs = node.a else {
                decryptionFailureReasons.append("\(node.h): sin atributos (a == nil)")
                continue
            }
            guard let keyString = node.k else {
                decryptionFailureReasons.append("\(node.h): sin clave (k == nil)")
                continue
            }
            let candidateKeys = crypto.parseNodeKeyCandidates(keyString, folderKey: folderKey)
            guard !candidateKeys.isEmpty else {
                decryptionFailureReasons.append("\(node.h): no se pudo desencriptar la clave (k=\(keyString.prefix(20))...)")
                continue
            }

            var attrs: [String: Any]?
            var matchedKey: Data?
            for candidateKey in candidateKeys {
                if let decryptedAttrs = crypto.decryptAttributes(encryptedAttrs, key: candidateKey),
                   decryptedAttrs["n"] as? String != nil {
                    attrs = decryptedAttrs
                    matchedKey = candidateKey
                    break
                }
            }

            guard let attrs, let fileKey = matchedKey else {
                decryptionFailureReasons.append("\(node.h): no se pudieron desencriptar los atributos con ninguna clave candidata")
                continue
            }
            guard let fileName = attrs["n"] as? String else {
                decryptionFailureReasons.append("\(node.h): atributos desencriptados sin campo de nombre (n)")
                continue
            }

            guard isAudioFileName(fileName) else {
                unsupportedExtensions.append(fileName)
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

        logger.info("""
            Mega sync: \(nodes.count) nodos totales -> \(files.count) canciones. \
            Descartados: \(folderCount) carpetas, \(decryptionFailureReasons.count) con fallo de desencriptación, \
            \(unsupportedExtensions.count) con extensión no soportada.
            """)
        if !unsupportedExtensions.isEmpty {
            logger.info("Mega sync: archivos con extensión no soportada: \(unsupportedExtensions.joined(separator: ", "))")
        }
        if !decryptionFailureReasons.isEmpty {
            for reason in decryptionFailureReasons {
                logger.info("Mega sync: fallo de desencriptación — \(reason)")
            }
        }

        return files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func isAudioFileName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return audioExtensions.contains { lower.hasSuffix($0) }
    }
}
