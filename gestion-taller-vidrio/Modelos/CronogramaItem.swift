import Foundation
import FirebaseFirestore

struct CronogramaItem: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var cursoId: String
    var cursoNombre: String
    var cursoTipo: TipoCurso
    var precio_curso: Double
    var fecha: Date
    
    // Es opcional para no romper si el documento es viejo y no tiene el campo aún.
    var cant_inscriptos: Int?
    var cupo_maximo: Int?   // Solo presenciales. Sin valor = sin límite.
    var notas: String?

    // Denormalizado de Curso.es_profesor_externo al crear la fecha.
    var es_profesor_externo: Bool? = nil

    // Solo talleres
    var hora_inicio: String?         // "HH:00", hora de apertura
    var hora_fin: String?            // "HH:00", hora de cierre
    var slot_ocupacion: [String: Int]? // "09": 2 — se lee, no se edita desde la app

    // Computed property defensiva para la UI
    var inscriptosReales: Int {
        return cant_inscriptos ?? 0
    }

    /// True si hay cupo definido y ya se alcanzó (con pagados/inscriptos firmes).
    var estaLleno: Bool {
        guard let cupo = cupo_maximo else { return false }
        return inscriptosReales >= cupo
    }
    
    // Implementación de Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(cursoId)
    }

    static func == (lhs: CronogramaItem, rhs: CronogramaItem) -> Bool {
        return lhs.id == rhs.id && lhs.cursoId == rhs.cursoId && lhs.fecha == rhs.fecha && lhs.cursoNombre == rhs.cursoNombre && lhs.cant_inscriptos == rhs.cant_inscriptos
    }
}

// MARK: - Compartir inscripción

extension CronogramaItem {
    var inscripcionURL: URL? {
        guard let docID = id else { return nil }
        return URL(string: "https://taller-glass-v2.web.app/inscribir/\(docID)")
    }

    /// Link público de preinscripción para cursos presenciales.
    var preinscripcionURL: URL? {
        guard let docID = id else { return nil }
        return URL(string: "https://taller-glass-v2.web.app/preinscribir/\(docID)")
    }

    /// Link a compartir según el tipo de curso: preinscripción para presenciales, inscripción para el resto.
    var linkCompartir: URL? {
        cursoTipo == .presencial ? preinscripcionURL : inscripcionURL
    }

    /// Formato normalizado "preinscriptos/inscriptos/cupo" para cards de cursos presenciales.
    /// Cupo indefinido se muestra como "-".
    func textoInscriptos(preinscriptos: Int) -> String {
        let cupoTexto = cupo_maximo.map(String.init) ?? "-"
        return "\(preinscriptos)/\(inscriptosReales)/\(cupoTexto)"
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
