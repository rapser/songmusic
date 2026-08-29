//
//  DurationFormatter.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer (formateo puro, sin dependencias)
//

import Foundation

/// Único punto de formateo de duraciones de la app. Antes había 6 implementaciones
/// repartidas por entidades y structs de stats, todas repitiendo la aritmética `/3600`.
enum DurationFormatter {

    /// Reloj de pista: `"03:45"`. `nil` (o valor inválido) → `"--:--"`.
    static func clock(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    enum HoursMinutesStyle {
        /// `"2 h 35 min"` / `"45 min"`
        case spaced
        /// `"2h 35m"` / `"45 min"`
        case compact
        /// `"2h 35m"` / `"0h 45m"` (siempre muestra horas)
        case compactAlways
    }

    /// Duración larga en horas y minutos.
    static func hoursMinutes(_ seconds: TimeInterval, style: HoursMinutesStyle) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        switch style {
        case .spaced:
            return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
        case .compact:
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"
        case .compactAlways:
            return "\(hours)h \(minutes)m"
        }
    }
}
