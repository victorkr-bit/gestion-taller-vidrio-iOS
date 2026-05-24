//
//  Formatters.swift
//  gestion-taller-vidrio
//
//  Created by Victor Krongold on 29/12/2025.
//


import Foundation

struct Formatters {
    
    // --- CONFIGURACIÓN PRIVADA (Solo se crea una vez) ---
    
    // Moneda Argentina sin decimales
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_AR")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
    
    // Fecha corta (Ej: 9 Dic 2025)
    private static let dateShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    // Hora (Ej: 18:30)
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // --- API PÚBLICA (Lo que usas en las vistas) ---
    
    static func money(_ value: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    /// Formato compacto para gráficos: $4,15M / $45K / $800
    static func compactMoney(_ value: Double) -> String {
        if value >= 1_000_000 {
            var s = String(format: "%.2f", value / 1_000_000)
                .replacingOccurrences(of: ".", with: ",")
            while s.hasSuffix("0") { s = String(s.dropLast()) }
            if s.hasSuffix(",") { s = String(s.dropLast()) }
            return "$\(s)M"
        } else if value >= 1_000 {
            var s = String(format: "%.1f", value / 1_000)
                .replacingOccurrences(of: ".", with: ",")
            while s.hasSuffix("0") { s = String(s.dropLast()) }
            if s.hasSuffix(",") { s = String(s.dropLast()) }
            return "$\(s)K"
        } else {
            return money(value)
        }
    }
    
    static func date(_ date: Date) -> String {
        // Capitalizamos (ej: "dic" -> "Dic")
        return dateShortFormatter.string(from: date).capitalized
    }
    
    static func time(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    // Fecha día/mes (Ej: 12/10)
    private static let dateDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()

    static func dateDayMonth(_ date: Date) -> String {
        return dateDayMonthFormatter.string(from: date)
    }

    // Configurada para manejar milisegundos (estándar común en backends)
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Solo fecha yyyy-MM-dd (para Cloud Functions que concatenan hora)
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        return formatter
    }()

    static func dateOnly(_ date: Date) -> String {
        return dateOnlyFormatter.string(from: date)
    }
}

// MARK: - Binding de texto numérico

import SwiftUI

extension Binding where Value == String {
    /// Retorna un Binding que solo permite dígitos numéricos.
    func numericOnly() -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                let filtered = newValue.filter { "0123456789".contains($0) }
                self.wrappedValue = filtered
            }
        )
    }
}
