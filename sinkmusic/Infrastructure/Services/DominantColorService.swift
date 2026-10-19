//
//  DominantColorService.swift
//  sinkmusic
//
//  Infrastructure Layer - Service
//

import Foundation
import UIKit

/// Calcula el color dominante de una carátula, para usarlo de fondo del reproductor.
///
/// Estaba como `static func` en una extensión de `SwiftUI.Color`, y se llamaba **desde el
/// mapper**: decodificar la imagen, pintarla en un buffer y muestrear píxeles, en el main
/// actor, una vez por fila de cada lista mientras el color no estuviera guardado. El color
/// solo lo lee el reproductor —una canción—, así que se calculaban N para usar uno.
///
/// Ahora se calcula una vez, al ingerir la canción (`MetadataService`, fuera del main
/// actor), se persiste, y el mapper solo lee lo guardado.
///
/// `nonisolated` y sin estado a propósito: se llama desde contextos de fondo.
enum DominantColorService {

    /// Cada cuántos píxeles se muestrea, en los dos ejes. La entrada es un thumbnail de
    /// 64×64, así que esto deja ~49 muestras: suficiente para el color de un fondo.
    private static let sampleStride = 10

    /// Se ignoran los píxeles casi negros y casi blancos: son los bordes y los brillos de
    /// la carátula, no su color, y un fondo hecho con ellos sale gris.
    private static let usableBrightness = 0.15...0.85

    /// Cuántos niveles por canal al agrupar colores parecidos. 10 niveles × 3 canales dan
    /// 1000 cubos: agrupa lo suficiente para que un degradado cuente como un solo color.
    private static let quantizationLevels = 10

    /// Color dominante de una imagen, ya ajustado para servir de fondo.
    /// - Returns: `nil` si la imagen no se puede leer o no tiene ningún píxel utilizable
    ///   (por ejemplo una carátula completamente negra).
    static func extract(from imageData: Data?) -> RGBColor? {
        guard let imageData,
              let cgImage = UIImage(data: imageData)?.cgImage else { return nil }
        return extract(from: cgImage)
    }

    private static func extract(from cgImage: CGImage) -> RGBColor? {
        guard let pixels = pixelBuffer(for: cgImage),
              let dominant = mostCommonColor(in: pixels, width: cgImage.width, height: cgImage.height)
        else { return nil }

        return adjustedForBackground(dominant)
    }

    // MARK: - Lectura de píxeles

    private static func pixelBuffer(for cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let drawn = pixelData.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerPixel * width,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        return drawn ? pixelData : nil
    }

    // MARK: - Color dominante

    private static func mostCommonColor(
        in pixelData: [UInt8],
        width: Int,
        height: Int
    ) -> (r: Double, g: Double, b: Double)? {
        let bytesPerPixel = 4
        let levels = quantizationLevels

        // La clave es un entero (el índice del cubo de color), no una cadena: antes se
        // construía un `"\(r)-\(g)-\(b)"` por muestra, con su asignación de memoria.
        var counts: [Int: (color: (r: Double, g: Double, b: Double), count: Int)] = [:]

        for x in stride(from: 0, to: width, by: sampleStride) {
            for y in stride(from: 0, to: height, by: sampleStride) {
                let index = ((width * y) + x) * bytesPerPixel

                let r = Double(pixelData[index]) / 255.0
                let g = Double(pixelData[index + 1]) / 255.0
                let b = Double(pixelData[index + 2]) / 255.0

                let brightness = (r + g + b) / 3.0
                guard usableBrightness.contains(brightness) else { continue }

                let bucket = Int(r * Double(levels)) * levels * levels
                    + Int(g * Double(levels)) * levels
                    + Int(b * Double(levels))

                if let existing = counts[bucket] {
                    counts[bucket] = (existing.color, existing.count + 1)
                } else {
                    counts[bucket] = ((r, g, b), 1)
                }
            }
        }

        return counts.max { $0.value.count < $1.value.count }?.value.color
    }

    /// Mantiene el matiz pero acota el brillo: un fondo demasiado oscuro o demasiado claro
    /// deja el texto blanco del reproductor ilegible.
    private static func adjustedForBackground(_ color: (r: Double, g: Double, b: Double)) -> RGBColor {
        let hsb = rgbToHSB(r: color.r, g: color.g, b: color.b)
        let adjusted = hsbToRGB(
            h: hsb.h,
            s: min(hsb.s * 0.95, 1.0),
            b: min(0.78, max(0.5, hsb.b * 0.85))
        )
        return RGBColor(red: adjusted.r, green: adjusted.g, blue: adjusted.b)
    }

    // MARK: - Conversiones HSB

    private static func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var h: Double = 0
        let s: Double = maxC == 0 ? 0 : delta / maxC

        if delta != 0 {
            if maxC == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h *= 60
            if h < 0 { h += 360 }
        }

        return (h / 360.0, s, maxC)
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let hue = h * 360
        let c = b * s
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c

        var r: Double = 0, g: Double = 0, blue: Double = 0

        switch hue {
        case 0..<60:    r = c; g = x; blue = 0
        case 60..<120:  r = x; g = c; blue = 0
        case 120..<180: r = 0; g = c; blue = x
        case 180..<240: r = 0; g = x; blue = c
        case 240..<300: r = x; g = 0; blue = c
        case 300..<360: r = c; g = 0; blue = x
        default:        break
        }

        return (r + m, g + m, blue + m)
    }
}
