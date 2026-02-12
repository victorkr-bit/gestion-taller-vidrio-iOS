import Foundation
import FirebaseFirestore

enum Origen: Identifiable {
    case pedido(Pedido)
    case inscripcion(Inscripcion)

    var id: String {
        switch self {
        case .pedido(let p): return p.id ?? UUID().uuidString
        case .inscripcion(let i): return i.id ?? UUID().uuidString
        }
    }

    var documentID: String? {
        switch self {
        case .pedido(let p): return p.id
        case .inscripcion(let i): return i.id
        }
    }

    var ref: DocumentReference? {
        guard let id = self.documentID else { return nil }
        let db = FirestoreManager.shared.db
        switch self {
        case .pedido:
            return db.collection("pedidos").document(id)
        case .inscripcion:
            return db.collection("inscripciones").document(id)
        }
    }

    var tipo: OrigenTipoPago {
        switch self {
        case .pedido: return .pedido
        case .inscripcion: return .inscripcion
        }
    }

    var clienteID: String {
        switch self {
        case .pedido(let p): return p.cliente_id
        case .inscripcion(let i): return i.alumnoId
        }
    }

    var clienteNombre: String {
        switch self {
        case .pedido(let p): return p.cliente_nombre
        case .inscripcion(let i): return i.alumno_nombre
        }
    }

    var descripcionOrigen: String {
        switch self {
        case .pedido(let p):
            return "Pago Pedido #\(p.numero_pedido)"

        case .inscripcion(let i):
            return "\(i.cursoNombre) (\(Formatters.dateDayMonth(i.fecha_curso)))"
        }
    }

    var montoAdeudado: Double {
        switch self {
        case .pedido(let p): return p.monto_adeudado
        case .inscripcion(let i): return i.monto_adeudado
        }
    }

    var tipoVenta: TipoVenta {
        switch self {
        case .pedido(let p):
            switch p.tipo {
            case .piezas: return .piezas
            case .materiales: return .materiales
            case .joyeria: return .joyeria
            case .otros: return .otros
            }
        case .inscripcion(let i):
            switch i.cursoTipo {
            case .presencial: return .presencial
            case .online: return .online
            case .taller: return .taller
            }
        }
    }
}
