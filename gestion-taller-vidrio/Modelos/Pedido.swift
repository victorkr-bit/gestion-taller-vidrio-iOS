import Foundation
import FirebaseFirestore

// Modelo para la coleccion "pedidos"
struct Pedido: Codable, Identifiable {
    @DocumentID var id: String?
    var numero_pedido: String
    var cliente_id: String
    var cliente_nombre: String
    var presupuesto: Double
    var monto_abonado: Double
    var monto_adeudado: Double
    var estado_pago: Bool
    var fecha: Date
    var descripcion: String
    var tipo: TipoPedido
    var estado_entrega: Bool
}

extension Pedido {
    
    // 1. Payload para CREAR (Se usa en createPedidoRemote)
    // Manda todos los datos necesarios para inicializar el pedido
    var asCloudPayload: [String: Any] {
        return [
            "clienteId": cliente_id,
            "clienteNombre": cliente_nombre,
            "descripcion": descripcion,
            "presupuesto": presupuesto,
            "tipo": tipo.rawValue,
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
