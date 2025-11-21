//
//  GoogleDriveService.swift
//  sinkmusic
//
//  Created by Claude Code
//

import Foundation

struct GoogleDriveFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String

    var title: String {
        // Extraer el título del nombre del archivo (sin extensión)
        let components = name.components(separatedBy: " - ")
        if components.count >= 2 {
            // Formato esperado: "Artista - Título.m4a"
            let titleWithExtension = components[1]
            return titleWithExtension.replacingOccurrences(of: ".m4a", with: "")
        }
        return name.replacingOccurrences(of: ".m4a", with: "")
    }

    var artist: String {
        // Extraer el artista del nombre del archivo
        let components = name.components(separatedBy: " - ")
        if components.count >= 2 {
            return components[0]
        }
        return "Artista Desconocido"
    }
}

struct GoogleDriveResponse: Codable {
    let files: [GoogleDriveFile]
}

class GoogleDriveService {
    private let apiKey = "AIzaSyB6_cJHOqvf9hNvdj8xj51K2lyQYohl1Sw"
    private let folderId = "1BZcNbgPjBN4uV0yjdO_-QY2K0a6xS4gv"

    // Obtener lista de archivos de la carpeta pública de Google Drive
    func fetchSongsFromFolder() async throws -> [GoogleDriveFile] {
        // URL de la API de Google Drive Files.list
        // Usando acceso público sin autenticación para carpetas compartidas
        let urlString = "https://www.googleapis.com/drive/v3/files"

        guard var components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }

        // Parámetros de consulta
        components.queryItems = [
            URLQueryItem(name: "q", value: "'\(folderId)' in parents and (mimeType='audio/mpeg' or mimeType='audio/mp4' or mimeType='audio/x-m4a')"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("🔍 Obteniendo canciones desde Google Drive...")
        print("📂 Folder ID: \(folderId)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("📡 HTTP Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }

        let driveResponse = try JSONDecoder().decode(GoogleDriveResponse.self, from: data)

        print("✅ \(driveResponse.files.count) archivos encontrados en Google Drive")

        // Filtrar solo archivos .m4a
        let m4aFiles = driveResponse.files.filter { file in
            file.name.hasSuffix(".m4a")
        }

        print("🎵 \(m4aFiles.count) archivos .m4a válidos encontrados")

        return m4aFiles
    }

    // Construir URL de descarga directa para un archivo de Google Drive
    func getDownloadURL(for fileId: String) -> String {
        return "https://drive.google.com/uc?export=download&id=\(fileId)"
    }
}
