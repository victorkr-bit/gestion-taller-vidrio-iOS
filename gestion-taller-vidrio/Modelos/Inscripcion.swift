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
    
    var fecha_curso: Date           // Copiado
    var precio_curso: Double        // Copiado
    var monto_abonado: Double
    var monto_adeudado: Double
    var estado: EstadoInscripcion   // Enum
    
    // Opcionales (solo aplican a talleres/agenda)
    var horario_inicio: String?
    var turnos: Int?

    var notas: String?
}
