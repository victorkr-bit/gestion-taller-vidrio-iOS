import Foundation

// Enum para el tipo de curso [cite: 169]
enum TipoCurso: String, Codable, CaseIterable, Identifiable {
    case presencial = "presencial"
    case online = "online"
    case taller = "taller"
    
    var id: String { self.rawValue }
    
    var descripcion: String {
        switch self {
        case .presencial: return "Presencial"
        case .online: return "Online"
        case .taller: return "Taller"
        }
    }
    
    // --- SOLUCIÓN DEL BUG ---
    // Implementamos un decodificador personalizado que perdona las mayúsculas.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        
        // Convertimos lo que venga a minúsculas antes de intentar coincidir
        if let tipo = TipoCurso(rawValue: rawString.lowercased()) {
            self = tipo
        } else {
            // Si llega algo totalmente desconocido (ej: "video"), fallamos con detalle
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "No se puede inicializar TipoCurso con el valor: '\(rawString)'"
            )
        }
    }
}

// Enum para el estado de la inscripción [cite: 207]
enum EstadoInscripcion: String, Codable, CaseIterable, Identifiable {
    case inscripto = "Inscripto"
    case pagado = "Pagado"
    
    var id: String { self.rawValue }
}

// Enum para el tipo de pedido [cite: 193]
enum TipoPedido: String, Codable, CaseIterable, Identifiable {
    case piezas = "Piezas"
    case materiales = "Materiales"
    case joyeria = "Joyeria"
    case otros = "Otros"
    
    var id: String { self.rawValue }
    
    // NUEVO: Propiedad para UI
    var descripcion: String {
        switch self {
        case .joyeria:
            return "Joyería" // Aquí aplicamos la corrección visual
        default:
            return self.rawValue // Los demás ya tienen mayúscula y están bien
        }
    }
}

// Enum para el tipo de venta (usado en Pagos) [cite: 218]
enum TipoVenta: String, Codable, CaseIterable, Identifiable {
    case piezas = "Piezas"
    case materiales = "Materiales"
    case joyeria = "Joyeria"
    case taller = "Taller"
    case online = "Online"
    case presencial = "Presencial"
    case otros = "Otros"
    
    var id: String { self.rawValue }
    
    // NUEVO: Propiedad para UI
    var descripcion: String {
        switch self {
        case .joyeria:
            return "Joyería" // Corrección visual
        default:
            return self.rawValue
        }
    }
}

// Enum para el medio de pago [cite: 215]
enum MedioDePago: String, Codable, CaseIterable, Identifiable {
    case efectivo = "Efectivo"
    case transferencia = "Transferencia"
    case mercadoPago = "Mercado Pago"
    case tarjeta = "Tarjeta"
    case paypal = "Paypal"
    case otros = "Otros"
    
    var id: String { self.rawValue }
}

// Enum para el origen del pago [cite: 221]
enum OrigenTipoPago: String, Codable {
    case pedido = "pedido"
    case inscripcion = "inscripcion"
    case ventaDirecta = "Venta Directa"
    
    var id: String { self.rawValue }
}

enum TallerError: Error, LocalizedError {
    case tienePagos
    case tieneInscriptos
    // Nuevo error para transacciones
    case origenNoEncontrado
    case pagoNoEncontrado
    // Error para la transacción
    case transaccionFallida(String)
    
    // Esto mostrará un mensaje amigable en las Alertas de la UI
    var errorDescription: String? {
        switch self {
        case .tienePagos:
            return "Operación bloqueada: El ítem tiene pagos asociados."
        case .tieneInscriptos:
            return "Operación bloqueada: El curso tiene alumnos inscriptos."
        case .origenNoEncontrado:
            return "Error de Transacción: No se encontró el pedido o inscripción original."
        case .pagoNoEncontrado:
            return "Error de Transacción: No se encontró el pago a modificar."
        case .transaccionFallida(let detalle):
            return "Error de Transacción: \(detalle)"
        }
    }
}

