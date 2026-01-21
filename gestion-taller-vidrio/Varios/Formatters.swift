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
    
    static func date(_ date: Date) -> String {
        // Capitalizamos (ej: "dic" -> "Dic")
        return dateShortFormatter.string(from: date).capitalized
    }
    
    static func time(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    static let uiLocale = Locale(identifier: "es")
}
