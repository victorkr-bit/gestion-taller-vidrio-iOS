

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
