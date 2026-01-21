import Foundation
import FirebaseFirestore

struct CronogramaItem: Codable, Identifiable {
    @DocumentID var id: String?
    var cursoId: String
    var cursoNombre: String
    var cursoTipo: TipoCurso
    var precio_curso: Double
    var fecha: Date
    
    // --- NUEVO CAMPO ---
    // Mapea el contador mantenido por el servidor.
    // Es opcional (Int?) para no romper si el documento es viejo y no tiene el campo aún.
    var cant_inscriptos: Int?
    
    // Computed property defensiva para la UI
    var inscriptosReales: Int {
        return cant_inscriptos ?? 0
    }
}
