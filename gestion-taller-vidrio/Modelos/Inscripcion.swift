import Foundation
import FirebaseFirestore

struct Inscripcion: Codable, Identifiable {
    @DocumentID var id: String?
    
    var alumnoId: String            // Ref a contactos
    var alumno_nombre: String       // Denormalizado
    
    // --- CAMBIO CRÍTICO ---
    // Antes: String (Obligatorio)
    // Ahora: String? (Opcional).
    // Razón: Cursos Online (Evergreen) vienen con cronogramaId: null
    var cronogramaId: String?
    
    // --- NUEVO CAMPO ---
    // Referencia fuerte al catálogo.
    // Para cursos online, este es el ID que importa.
    // Lo agrego opcional porque tus inscripciones viejas quizás no lo tengan.
    var cursoId: String?
    
    var cursoNombre: String         // Denormalizado
    var cursoTipo: TipoCurso        // Denormalizado
    
    var fecha_inscripcion: FechaFlexible? // Timestamp de creación (nil en registros anteriores)
    var fecha_curso: Date                // Copiado
    var precio_curso: Double        // Copiado
    var monto_abonado: Double
    var monto_adeudado: Double
    var estado: EstadoInscripcion   // Enum

    // Opcionales (solo aplican a talleres/agenda)
    var horario_inicio: String?
    var turnos: Int?

    var notas: String?

    // Denormalizado de Curso.es_profesor_externo. Cuando es true, monto_abonado
    // se compone de total_adelanto (profesor, no entra a caja) + total_pago (usuaria, caja).
    var es_profesor_externo: Bool? = nil
    var total_adelanto: Double? = nil
    var total_pago: Double? = nil
}

// Wrapper tolerante para fecha_inscripcion: acepta Timestamp, String ISO8601, o ausencia
// sin lanzar error (lo que descargaría el documento completo al decodificar).
struct FechaFlexible: Codable {
    let value: Date?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Date.self)   { value = d; return }
        if let s = try? c.decode(String.self) { value = Formatters.iso8601.date(from: s); return }
        value = nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}
