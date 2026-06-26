import Foundation
import FirebaseFirestore

/// Estado de una preinscripción pública a un curso presencial.
/// El alumno se preinscribe desde la web → `pendiente`; el admin confirma el pago → `convertida`,
/// o la descarta → `cancelada`.
enum EstadoPreinscripcion: String, Codable {
    case pendiente
    case convertida
    case cancelada
}

/// Documento de la colección `preinscripciones` (backend compartido con la web).
/// La preinscripción NO crea contacto: el contacto se busca/crea recién al confirmar el pago
/// vía la Cloud Function `confirmarPreinscripcion`.
struct Preinscripcion: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let cronogramaId: String
    let cursoNombre: String
    let cursoTipo: String                 // "presencial"
    let fecha_curso: Timestamp
    let precio_curso: Double
    let nombre: String
    let apellido: String
    let email: String?
    let telefono: String?
    let notas: String?
    let estado: EstadoPreinscripcion
    let fecha_preinscripcion: Timestamp?  // nil un instante por serverTimestamp recién creado
    let contacto_id: String?
    let inscripcion_id: String?

    var nombreCompleto: String { "\(nombre) \(apellido)" }

    /// Contacto resumido para mostrar bajo el nombre (email o, si falta, teléfono).
    var contactoResumen: String? {
        if let email, !email.isEmpty { return email }
        if let telefono, !telefono.isEmpty { return telefono }
        return nil
    }
}
