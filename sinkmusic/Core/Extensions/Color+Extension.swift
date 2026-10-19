
import SwiftUI

extension Color {
    // Colores de la app
    static let appDark = Color(red: 25/255, green: 20/255, blue: 20/255)
    static let appPurple = Color(red: 138/255, green: 43/255, blue: 226/255)  // #8A2BE2
    static let appGray = Color(red: 40/255, green: 40/255, blue: 40/255)
    static let textGray = Color(red: 179/255, green: 179/255, blue: 179/255)

    /// Construye un `Color` desde el color de dominio.
    ///
    /// Esta extensión tenía además el análisis de la carátula —decodificar, pintar en un
    /// buffer y muestrear píxeles— detrás de un `static func` que parecía trivial y se
    /// llamaba desde el mapper, en el main actor, por cada fila. Vive en
    /// `DominantColorService` y se calcula al ingerir la canción.
    init(_ rgb: RGBColor) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
