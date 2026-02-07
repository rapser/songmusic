//
//  MegaAPIClient.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//
//  Cliente HTTP para la API de Mega. Solo peticiones y respuestas.
//  No conoce EventBus ni desencriptación.
//

import Foundation

/// Cliente para llamadas a la API de Mega (listar carpeta, obtener URL de descarga)
final class MegaAPIClient: Sendable {

    static let defaultBaseURL = "https://g.api.mega.co.nz/cs"

    private let baseURL: String

    init(baseURL: String = defaultBaseURL) {
        self.baseURL = baseURL
    }

    // MARK: - Folder

    /// Obtiene el contenido de una carpeta (recursivo)
    func fetchFolder(nodeId: String) async throws -> MegaFolderResponse {
        guard let url = URL(string: "\(baseURL)?id=\(Int.random(in: 0..<Int.max))&n=\(nodeId)") else {
            throw MegaError.invalidFolderURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [["a": "f", "c": 1, "r": 1, "ca": 1]])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(data: data, response: response)

        guard let responseArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = responseArray.first else {
            try Self.throwIfErrorCode(data: data)
            throw MegaError.apiError("Respuesta vacía")
        }

        let responseData = try JSONSerialization.data(withJSONObject: first)
        return try JSONDecoder().decode(MegaFolderResponse.self, from: responseData)
    }

    // MARK: - Download URL

    /// Obtiene una URL temporal de descarga para un archivo
    func getDownloadURL(fileId: String, folderHandle: String?) async throws -> URL {
        var urlString = "\(baseURL)?id=\(Int.random(in: 0..<Int.max))"
        if let handle = folderHandle {
            urlString += "&n=\(handle)"
        }

        guard let url = URL(string: urlString) else {
            throw MegaError.invalidFolderURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [["a": "g", "g": 1, "n": fileId]])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(data: data, response: response)

        guard let responseArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = responseArray.first,
              let downloadURLString = first["g"] as? String else {
            try Self.throwIfErrorCode(data: data, fileId: fileId, folderHandle: folderHandle)
            throw MegaError.apiError("No se pudo obtener URL de descarga")
        }

        guard let downloadURL = URL(string: downloadURLString) else {
            throw MegaError.apiError("URL de descarga inválida")
        }

        return downloadURL
    }

    // MARK: - Response Helpers

    private static func checkResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MegaError.apiError("Respuesta inválida")
        }
        if http.statusCode == 509 {
            throw MegaError.rateLimitExceeded(retryAfter: parseRetryAfter(http))
        }
        guard http.statusCode == 200 else {
            throw MegaError.apiError("HTTP \(http.statusCode)")
        }
    }

    private static func throwIfErrorCode(data: Data, fileId: String? = nil, folderHandle: String? = nil) throws {
        guard let codes = try? JSONSerialization.jsonObject(with: data) as? [Int],
              let code = codes.first, code < 0 else {
            return
        }
        switch code {
        case -9:
            throw MegaError.fileNotFound
        case -18:
            throw MegaError.rateLimitExceeded(retryAfter: 3600)
        default:
            throw MegaError.apiError("Código de error: \(code)")
        }
    }

    static func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval {
        if let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = TimeInterval(value) {
            return seconds
        }
        return 3600
    }
}
