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
    
    // Computed property para UI
    var inscriptosTotales: Int {
        return cant_inscriptos ?? 0
    }
}
