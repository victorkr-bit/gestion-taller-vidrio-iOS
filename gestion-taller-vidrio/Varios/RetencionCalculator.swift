import Foundation

/// Calcula, por mes, cuántos alumnos son "nuevos" vs. "repiten" en presencial/taller.
/// Puerto 1:1 de `computeRetentionByMonth` (repo web, `retentionCalculator.ts`).
struct RetencionCalculator {

    /// Un alumno es "nuevo" solo la primera vez que aparece en cualquier tipo de curso
    /// (incluyendo online). Online no se grafica, pero sí marca al alumno como visto.
    /// Las inscripciones ya llegan sin canceladas (`EstadoInscripcion` no admite ese caso).
    static func porMes(inscripciones: [Inscripcion]) -> [String: (nuevos: Int, repiten: Int)] {
        let ordenadas = inscripciones.sorted {
            fechaOrden($0) < fechaOrden($1)
        }

        var vistos = Set<String>()
        var conteo: [String: (nuevos: Int, repiten: Int)] = [:]

        for inscripcion in ordenadas {
            let esNuevo = !vistos.contains(inscripcion.alumnoId)
            vistos.insert(inscripcion.alumnoId)

            guard inscripcion.cursoTipo == .presencial || inscripcion.cursoTipo == .taller else {
                continue
            }

            let clave = mesAño(fechaOrden(inscripcion))
            var actual = conteo[clave] ?? (nuevos: 0, repiten: 0)
            if esNuevo {
                actual.nuevos += 1
            } else {
                actual.repiten += 1
            }
            conteo[clave] = actual
        }

        return conteo
    }

    private static func fechaOrden(_ inscripcion: Inscripcion) -> Date {
        inscripcion.fecha_inscripcion?.value ?? inscripcion.fecha_curso
    }

    private static func mesAño(_ fecha: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let m = cal.component(.month, from: fecha)
        let a = cal.component(.year, from: fecha)
        return String(format: "%04d-%02d", a, m)
    }
}
