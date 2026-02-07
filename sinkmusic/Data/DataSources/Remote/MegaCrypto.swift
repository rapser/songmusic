//
//  MegaCrypto.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Utilidades de encriptación para Mega
//

import Foundation
import CommonCrypto

/// Utilidades de encriptación/desencriptación para archivos de Mega
/// Mega usa AES-128-CTR para encriptar archivos
struct MegaCrypto {

    // MARK: - Base64 URL-Safe Decoding

    /// Decodifica una clave de Mega desde Base64 URL-safe
    /// Mega usa Base64 modificado: - en lugar de +, _ en lugar de /, sin padding
    func decodeBase64URL(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Agregar padding si es necesario
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }

    // MARK: - Folder Key Parsing

    /// Extrae el nodeId y la clave de una URL de carpeta de Mega
    /// Formato: https://mega.nz/folder/{nodeId}#{key}
    func parseFolderURL(_ url: String) throws -> (nodeId: String, key: Data) {
        // Formato nuevo: https://mega.nz/folder/xxxxx#yyyyy
        // Formato antiguo: https://mega.nz/#F!xxxxx!yyyyy

        let newPattern = #"mega\.nz/folder/([A-Za-z0-9_-]+)#([A-Za-z0-9_-]+)"#
        let oldPattern = #"mega\.nz/#F!([A-Za-z0-9_-]+)!([A-Za-z0-9_-]+)"#

        if let match = url.range(of: newPattern, options: .regularExpression) {
            let components = url[match].components(separatedBy: CharacterSet(charactersIn: "/#"))
            if components.count >= 2 {
                let nodeId = components[components.count - 2]
                let keyString = components[components.count - 1]

                guard let keyData = decodeBase64URL(keyString) else {
                    throw MegaError.invalidFileKey
                }

                return (nodeId, keyData)
            }
        }

        if let match = url.range(of: oldPattern, options: .regularExpression) {
            let components = url[match].components(separatedBy: "!")
            if components.count >= 3 {
                let nodeId = components[1]
                let keyString = components[2]

                guard let keyData = decodeBase64URL(keyString) else {
                    throw MegaError.invalidFileKey
                }

                return (nodeId, keyData)
            }
        }

        throw MegaError.invalidFolderURL
    }

    // MARK: - Key Derivation

    /// Deriva la clave AES de 128 bits desde la clave de Mega
    /// Mega usa una clave de 256 bits donde los primeros 128 bits XOR con los últimos 128 bits
    func deriveAESKey(from megaKey: Data) -> Data {
        guard megaKey.count >= 16 else {
            return megaKey
        }

        if megaKey.count == 16 {
            return megaKey
        }

        // Para claves de 32 bytes (256 bits), XOR las dos mitades
        if megaKey.count == 32 {
            var result = Data(count: 16)
            for i in 0..<16 {
                result[i] = megaKey[i] ^ megaKey[i + 16]
            }
            return result
        }

        return megaKey.prefix(16)
    }

    /// Desencripta la clave del archivo usando la clave de la carpeta
    func decryptFileKey(encryptedKey: Data, folderKey: Data) -> Data? {
        let aesKey = deriveAESKey(from: folderKey)
        return decryptAESECB(data: encryptedKey, key: aesKey)
    }

    // MARK: - AES ECB Decryption (for keys and attributes)

    /// Desencripta datos usando AES-ECB (usado para claves y atributos)
    func decryptAESECB(data: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256 else {
            return nil
        }

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, key.count,
                        nil, // No IV for ECB
                        dataPtr.baseAddress, data.count,
                        bufferPtr.baseAddress, bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return buffer.prefix(numBytesDecrypted)
    }

    // MARK: - AES CTR Decryption (for file content)

    /// Desencripta un archivo usando AES-128-CTR
    /// La clave del archivo contiene tanto la clave AES como el IV/nonce
    func decryptFile(encryptedData: Data, fileKey: Data) -> Data? {
        // La clave del archivo tiene 32 bytes:
        // - Bytes 0-15: Clave AES
        // - Bytes 16-23: Nonce/IV (8 bytes)
        // - Bytes 24-31: Meta MAC (no usado para desencriptación)

        guard fileKey.count >= 24 else {
            return nil
        }

        // Derivar clave AES de 128 bits
        let aesKey = deriveAESKey(from: fileKey)

        // Extraer nonce (bytes 16-23) y extender a 16 bytes
        let nonceStart = min(16, fileKey.count)
        let nonceEnd = min(24, fileKey.count)
        var nonce = Data(count: 16)

        if nonceEnd > nonceStart {
            let nonceData = fileKey[nonceStart..<nonceEnd]
            for (i, byte) in nonceData.enumerated() where i < 8 {
                nonce[i] = byte
            }
        }

        return decryptAESCTR(data: encryptedData, key: aesKey, nonce: nonce)
    }

    /// Desencripta datos usando AES-128-CTR
    func decryptAESCTR(data: Data, key: Data, nonce: Data) -> Data? {
        guard key.count == 16, nonce.count == 16 else {
            return nil
        }

        var result = Data(count: data.count)
        var counter = nonce

        let blockSize = 16
        let blockCount = (data.count + blockSize - 1) / blockSize

        for blockIndex in 0..<blockCount {
            // Encriptar el contador para obtener el keystream
            guard let keystream = encryptAESECB(data: counter, key: key) else {
                return nil
            }

            // XOR del keystream con el bloque de datos
            let dataStart = blockIndex * blockSize
            let dataEnd = min(dataStart + blockSize, data.count)

            for i in dataStart..<dataEnd {
                result[i] = data[i] ^ keystream[i - dataStart]
            }

            // Incrementar contador
            incrementCounter(&counter)
        }

        return result
    }

    /// Encripta datos usando AES-ECB (para generar keystream en CTR)
    private func encryptAESECB(data: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 else {
            return nil
        }

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, key.count,
                        nil,
                        dataPtr.baseAddress, data.count,
                        bufferPtr.baseAddress, bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return buffer.prefix(numBytesEncrypted)
    }

    /// Incrementa el contador de 128 bits (big-endian)
    private func incrementCounter(_ counter: inout Data) {
        for i in (0..<counter.count).reversed() {
            counter[i] = counter[i] &+ 1
            if counter[i] != 0 {
                break
            }
        }
    }

    // MARK: - Attributes Decryption

    /// Desencripta los atributos de un nodo (nombre del archivo, etc.)
    /// Los atributos están encriptados con AES-CBC y tienen formato JSON con prefijo "MEGA"
    func decryptAttributes(_ encryptedBase64: String, key: Data) -> [String: Any]? {
        guard let encryptedData = decodeBase64URL(encryptedBase64) else {
            return nil
        }

        let aesKey = deriveAESKey(from: key)

        // Los atributos usan AES-CBC con IV de ceros
        guard let decrypted = decryptAESCBC(data: encryptedData, key: aesKey) else {
            return nil
        }

        // Buscar el prefijo "MEGA" y extraer JSON
        guard let string = String(data: decrypted, encoding: .utf8) else {
            return nil
        }

        // El formato es "MEGA{...}" donde {...} es JSON
        if let megaRange = string.range(of: "MEGA{"),
           let endRange = string.range(of: "}", range: megaRange.upperBound..<string.endIndex) {

            let jsonStart = string.index(megaRange.upperBound, offsetBy: -1)
            let jsonString = String(string[jsonStart...endRange.lowerBound])

            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return json
            }
        }

        return nil
    }

    /// Desencripta datos usando AES-CBC con IV de ceros
    func decryptAESCBC(data: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256 else {
            return nil
        }

        let iv = Data(count: kCCBlockSizeAES128) // IV de ceros
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(0), // No padding option for CBC
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        // Remover padding PKCS7
        var result = buffer.prefix(numBytesDecrypted)
        if let lastByte = result.last, lastByte > 0 && lastByte <= 16 {
            let paddingLength = Int(lastByte)
            if paddingLength <= result.count {
                result = result.prefix(result.count - paddingLength)
            }
        }

        return result
    }

    // MARK: - Key String Parsing

    /// Parsea la clave de un nodo desde el formato de Mega
    /// Formato: "userHandle:encryptedKey" o solo "encryptedKey"
    func parseNodeKey(_ keyString: String, folderKey: Data) -> Data? {
        // El formato puede ser "handle:base64key" o solo "base64key"
        let parts = keyString.components(separatedBy: ":")
        let keyPart = parts.count > 1 ? parts[1] : parts[0]

        guard let encryptedKey = decodeBase64URL(keyPart) else {
            return nil
        }

        // Desencriptar la clave del archivo usando la clave de la carpeta
        return decryptFileKey(encryptedKey: encryptedKey, folderKey: folderKey)
    }
}
