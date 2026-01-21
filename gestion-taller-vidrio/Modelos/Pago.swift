//
//  Pago.swift
//  gestiontaller
//
//  Created by Victor Krongold on 13/11/2025.
//


import Foundation
import FirebaseFirestore

// Modelo para la coleccion "pagos"
struct Pago: Codable, Identifiable {
    @DocumentID var id: String?
    var fecha: Date // Timestamp [cite: 213]
    var monto: Double // [cite: 214]
    var medio_de_pago: MedioDePago // Enum [cite: 215]
    var cliente_id: String // Ref a contactos [cite: 216]
    var cliente_nombre: String // Denormalizado [cite: 217]
    var tipo_venta: TipoVenta // Enum [cite: 218]
    
    // Opcionales según lo definido
    var notas: String? // [cite: 220]
    
    // Campos de Origen
    var origen_tipo: OrigenTipoPago // Enum [cite: 221]
    var descripcion_origen: String // Ej: "Pago Pedido #PED-001" [cite: 223]
    
    // Opcional (null para Venta Directa) [cite: 222]
    var origen_id: String? // Ref a pedidos o inscripciones
}
