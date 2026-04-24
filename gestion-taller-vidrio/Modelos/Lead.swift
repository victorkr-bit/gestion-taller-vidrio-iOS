import SwiftUI
import FirebaseFirestore

struct Lead: Identifiable, Codable {
    @DocumentID var id: String?
    var nombre: String
    var canal: String
    var contacto: String
    var curso_interes: String
    var notas: String
    var estado: EstadoLead
    var fecha_ingreso: FechaFlexible?
    var contacto_id: String?
}

enum EstadoLead: String, Codable, CaseIterable {
    case pendiente
    case notificado
    case convertido

    var label: String {
        switch self {
        case .pendiente:  "Pendiente"
        case .notificado: "Notificado"
        case .convertido: "Convertido"
        }
    }

    var color: Color {
        switch self {
        case .pendiente:  DesignSystem.Color.alerta
        case .notificado: DesignSystem.Color.accion
        case .convertido: DesignSystem.Color.exito
        }
    }
}
