//
//  AudioEqualizer.swift
//  sinkmusic
//
//  Infrastructure Layer - Service
//

import Foundation
import AVFoundation

/// El ecualizador paramétrico de 6 bandas del grafo de audio.
///
/// Vivía dentro de `AudioPlayerService`, que ya tenía bastante con el grafo, el reloj, la
/// sesión y las interrupciones. Ecualizar no depende de nada de eso: es configurar un nodo.
/// Separado se puede probar sin motor ni sesión de audio —`AVAudioUnitEQ` acepta
/// parámetros estando suelto—, y el servicio solo tiene que conectar `node` a la cadena.
///
/// **Neutro por defecto**: todas las bandas arrancan en bypass y una banda a 0 dB vuelve a
/// bypass, así que la señal pasa sin tocarse mientras el usuario no mueva nada. Es la misma
/// decisión que el mixer neutro del servicio: no colorear el sonido salvo petición expresa.
@MainActor
final class AudioEqualizer {

    /// Centros de banda, en Hz. Definen cuántas bandas tiene el ecualizador: el resto del
    /// código deriva de aquí en vez de repetir el número 6.
    static let frequencies: [Float] = [60, 150, 400, 1000, 2400, 15000]

    /// Ancho de banda en octavas. 1.0 es la curva suave habitual en ecualizadores de
    /// consumo: toca la vecindad de la frecuencia sin estrechar en un pico.
    private static let bandwidthInOctaves: Float = 1.0

    private let unit: AVAudioUnitEQ

    /// El nodo a conectar en el grafo de audio.
    var node: AVAudioNode { unit }

    /// Ganancias actuales en dB, una por banda. Para inspección y tests.
    var gains: [Float] { unit.bands.map(\.gain) }

    /// Qué bandas están en bypass ahora mismo. Para inspección y tests.
    var bypassedBands: [Bool] { unit.bands.map(\.bypass) }

    init() {
        unit = AVAudioUnitEQ(numberOfBands: Self.frequencies.count)

        for (index, band) in unit.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Self.frequencies[index]
            band.bandwidth = Self.bandwidthInOctaves
            band.gain = 0
            band.bypass = true
        }
    }

    /// Aplica las ganancias en dB, una por banda y en el orden de `frequencies`.
    ///
    /// Sobran las que excedan el número de bandas y las que falten se dejan como estaban:
    /// quien llama viene de la UI y no debe poder romper el grafo pasando un array de otro
    /// tamaño.
    func apply(gains: [Float]) {
        for (index, gain) in gains.enumerated() where index < unit.bands.count {
            let band = unit.bands[index]
            band.gain = gain
            // A 0 dB la banda no hace nada: en bypass evita el coste y el ruido de cálculo.
            band.bypass = (gain == 0)
        }
    }

    /// Devuelve el ecualizador a plano y en bypass: señal sin procesar.
    func reset() {
        apply(gains: Array(repeating: 0, count: unit.bands.count))
    }
}
