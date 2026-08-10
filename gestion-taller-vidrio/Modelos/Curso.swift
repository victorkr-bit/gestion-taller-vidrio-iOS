import Foundation
import FirebaseFirestore

struct Curso: Codable, Identifiable {
    @DocumentID var id: String?
    var nombre: String
    var tipo: TipoCurso // Enum
    var precio: Double

    // --- NUEVO CAMPO ---
    // Contador acumulativo global para cursos Evergreen
    var cant_inscriptos: Int?

    // Curso presencial dictado por un profesor externo: el cobro se reparte entre
    // adelanto (profesor) y pago (usuaria). Solo se define al crear el curso.
    var es_profesor_externo: Bool? = nil

    // Computed property para UI
    var inscriptosTotales: Int {
        return cant_inscriptos ?? 0
    }
}
