

import Foundation
import FirebaseFirestore

// Modelo para la coleccion "pedidos"
struct Pedido: Codable, Identifiable {
    @DocumentID var id: String?
    var numero_pedido: String // ej: "PED-0001" [cite: 184]
    var cliente_id: String // Ref a contactos [cite: 185]
    var cliente_nombre: String // Denormalizado [cite: 186]
    var presupuesto: Double // [cite: 187]
    var monto_abonado: Double // [cite: 188]
    var monto_adeudado: Double // [cite: 189]
    var estado_pago: Bool // [cite: 190]
    var fecha: Date // Timestamp [cite: 191]
    var descripcion: String // [cite: 192]
    var tipo: TipoPedido // Enum [cite: 193]
    var estado_entrega: Bool // [cite: 194]
}

extension Pedido {
    
    // 1. Payload para CREAR (Se usa en createPedidoRemote)
    // Manda todos los datos necesarios para inicializar el pedido
    var asCloudPayload: [String: Any] {
        return [
            // "id": No lo mandamos porque lo genera Firebase o la Cloud Function
            "clienteId": cliente_id,
            "clienteNombre": cliente_nombre,
            "descripcion": descripcion,
            "presupuesto": presupuesto,
            "tipo": tipo.rawValue, // Importante: Mandar el String, no el Enum
            // La fecha la puede poner el servidor, o la mandamos nosotros formateada:
            "fecha": Formatters.iso8601.string(from: fecha)
        ]
    }
    
    // 2. Payload para ACTUALIZAR (Se usa en updatePedidoRemote)
    // Solo manda los campos que permitimos editar desde la App + el ID
    var updatePayload: [String: Any] {
        // Usamos un formatter ISO8601 estándar
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return [
            "cliente_nombre": cliente_nombre,
            "descripcion": descripcion,
            "presupuesto": presupuesto,
            "tipo": tipo.rawValue,
            "fecha": Formatters.iso8601.string(from: fecha),
            "estado_entrega": estado_entrega
            // NOTA CRÍTICA: NO enviamos 'monto_adeudado' ni 'monto_abonado'.
            // La Cloud Function 'actualizarPedido' se encarga de calcular eso
            // para evitar inconsistencias financieras.
        ]
    }
}
