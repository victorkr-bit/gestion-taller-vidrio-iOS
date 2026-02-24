import Foundation
import FirebaseFirestore

struct CronogramaItem: Codable, Identifiable, Hashable {
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
    
    // Implementación de Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(cursoId)
    }

    static func == (lhs: CronogramaItem, rhs: CronogramaItem) -> Bool {
        return lhs.id == rhs.id && lhs.cursoId == rhs.cursoId && lhs.fecha == rhs.fecha
    }
}

// MARK: - Compartir inscripción

extension CronogramaItem {
    var inscripcionURL: URL? {
        guard let docID = id else { return nil }
        return URL(string: "https://taller-glass-v2.web.app/inscribir/\(docID)")
    }

    var mensajeCompartir: String {
        let fechaFormateada = "\(Formatters.date(fecha)) \(Formatters.time(fecha))"

        return """
        ¡Hola! Te invito a inscribirte al curso de *\(cursoNombre)*.

        📅 Fecha: \(fechaFormateada)

        👇 Inscribite en el siguiente enlace:
        """
    }
}
