
import SwiftUI
import UIKit

extension Color {
    // Colores de la app
    static let appDark = Color(red: 25/255, green: 20/255, blue: 20/255)
    static let appPurple = Color(red: 138/255, green: 43/255, blue: 226/255)  // #8A2BE2
    static let appGray = Color(red: 40/255, green: 40/255, blue: 40/255)
    static let textGray = Color(red: 179/255, green: 179/255, blue: 179/255)

    /// Extrae el color dominante de los datos de imagen
    /// - Parameter imageData: Datos de la imagen (artwork)
    /// - Returns: Color dominante o appGray si no se puede calcular
    static func dominantColor(from imageData: Data?) -> Color {
        guard let rgb = dominantColorRGB(from: imageData) else { return Color.appGray }
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    /// Extrae el color dominante como componentes RGB (para persistir y reutilizar).
    /// - Parameter imageData: Datos de la imagen (artwork)
    /// - Returns: (r, g, b) en 0...1 o nil si no se puede calcular
    static func dominantColorRGB(from imageData: Data?) -> (r: Double, g: Double, b: Double)? {
        guard let imageData = imageData,
              let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        return extractDominantColorRGB(from: cgImage)
    }

    private static func extractDominantColor(from cgImage: CGImage) -> Color {
        guard let rgb = extractDominantColorRGB(from: cgImage) else {
            return Color.appGray
        }
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private static func extractDominantColorRGB(from cgImage: CGImage) -> (r: Double, g: Double, b: Double)? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Muestrear píxeles en una cuadrícula para mejor rendimiento
        var colorCounts: [String: (color: (r: Double, g: Double, b: Double), count: Int)] = [:]
        let sampleRate = 10
        
        for x in stride(from: 0, to: width, by: sampleRate) {
            for y in stride(from: 0, to: height, by: sampleRate) {
                let pixelIndex = ((width * y) + x) * bytesPerPixel
                
                let r = Double(pixelData[pixelIndex]) / 255.0
                let g = Double(pixelData[pixelIndex + 1]) / 255.0
                let b = Double(pixelData[pixelIndex + 2]) / 255.0
                
                // Ignorar colores muy oscuros o muy claros
                let brightness = (r + g + b) / 3.0
                guard brightness > 0.15 && brightness < 0.85 else { continue }
                
                // Agrupar colores similares
                let key = "\(Int(r * 10))-\(Int(g * 10))-\(Int(b * 10))"
                if var existing = colorCounts[key] {
                    existing.count += 1
                    colorCounts[key] = existing
                } else {
                    colorCounts[key] = ((r, g, b), 1)
                }
            }
        }
        
        // Encontrar el color más común
        guard let dominantColor = colorCounts.max(by: { $0.value.count < $1.value.count })?.value.color else {
            return nil
        }
        
        // Ajustar para fondo: mantener matiz y variedad, brillo medio para que se distingan los colores
        let hsb = rgbToHSB(r: dominantColor.r, g: dominantColor.g, b: dominantColor.b)
        let adjusted = hsbToRGB(
            h: hsb.h,
            s: min(hsb.s * 0.95, 1.0),
            b: min(0.78, max(0.5, hsb.b * 0.85))
        )
        return (adjusted.r, adjusted.g, adjusted.b)
    }
    
    private static func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        var h: Double = 0
        let s: Double = maxC == 0 ? 0 : delta / maxC
        let brightness = maxC
        
        if delta != 0 {
            if maxC == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h *= 60
            if h < 0 {
                h += 360
            }
        }
        
        return (h / 360.0, s, brightness)
    }
    
    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let hue = h * 360
        let c = b * s
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        
        var r: Double = 0, g: Double = 0, blue: Double = 0
        
        switch hue {
        case 0..<60:
            r = c; g = x; blue = 0
        case 60..<120:
            r = x; g = c; blue = 0
        case 120..<180:
            r = 0; g = c; blue = x
        case 180..<240:
            r = 0; g = x; blue = c
        case 240..<300:
            r = x; g = 0; blue = c
        case 300..<360:
            r = c; g = 0; blue = x
        default:
            break
        }
        
        return (r + m, g + m, blue + m)
    }
}
