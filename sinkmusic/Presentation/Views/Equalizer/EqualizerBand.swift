//
//  EqualizerBand.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct EqualizerBand {
    let frequency: String
    let label: String
    var gain: Double // -12 to +12 dB

    static let defaultBands: [EqualizerBand] = [
        EqualizerBand(frequency: "60", label: "60 Hz", gain: 0),
        EqualizerBand(frequency: "150", label: "150 Hz", gain: 0),
        EqualizerBand(frequency: "400", label: "400 Hz", gain: 0),
        EqualizerBand(frequency: "1k", label: "1 KHz", gain: 0),
        EqualizerBand(frequency: "2.4k", label: "2.4 KHz", gain: 0),
        EqualizerBand(frequency: "15k", label: "15 KHz", gain: 0),
    ]
}