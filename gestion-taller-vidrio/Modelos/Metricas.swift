//
//  MetricasFinancieras.swift
//  gestion-taller-vidrio
//
//  Created by Victor Krongold on 13/12/2025.
//


import Foundation
import FirebaseFirestore

struct MetricasFinancieras: Codable {
    // Si la base es nueva, estos campos pueden no existir, por eso damos valor por defecto.
    var total_deuda_pedidos: Double = 0.0
    var total_deuda_inscripciones: Double = 0.0
    
    // Propiedad computada para el Dashboard
    var deudaTotal: Double {
        return total_deuda_pedidos + total_deuda_inscripciones
    }
}