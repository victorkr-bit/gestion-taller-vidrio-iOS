import Foundation

/// Struct de datos para el gráfico de barras del Dashboard.
struct OcupacionHoraDato: Identifiable {
    var id: Int { hora }
    let hora: Int // La hora (ej: 9, 10, 11)
    let horaString: String // "9:00"
    var cantidad: Int
}

struct TallerCalculator {

    // MARK: - Cálculo de Ocupación por Alumno

    /**
     * Calcula la ocupación para un alumno específico, comparándolo contra la lista.
     * La lógica es: "cuántos alumnos (B, C, D...) se superponen con la hora de inicio del alumno A".
     * Se usa en `AgendaViewModel`.
     */
    static func calcularOcupacion(para alumno: Inscripcion, enLista: [Inscripcion]) -> Int {

        // 1. Obtener el inicio del alumno principal (A) en minutos.
        guard let inicioA = minutosDesdeMedianoche(from: alumno.horario_inicio) else {
            return 0
        }

        var ocupacion = 0

        // 2. Iterar sobre todos (incluyéndose a sí mismo)
        for otroAlumno in enLista {

            // 3. Obtener el rango del "otro" alumno (B)
            guard let inicioB = minutosDesdeMedianoche(from: otroAlumno.horario_inicio),
                  let turnosB = otroAlumno.turnos else {
                continue
            }

            // Fin del rango: ej. 14:00 + 2 turnos = 16:00 → rango [840, 960)
            let finB = inicioB + (turnosB * 60)

            // 4. Superposición: ¿el rango [inicioB, finB) contiene el instante inicioA?
            if inicioB <= inicioA && finB > inicioA {
                ocupacion += 1
            }
        }
        return ocupacion
    }

    // MARK: - Ocupación por Hora (la mantiene el backend)

    /// Horario por defecto del taller, para docs viejos sin `hora_inicio`/`hora_fin`.
    private static let aperturaPorDefecto = 13
    private static let cierrePorDefecto = 21

    /**
     * Lee la ocupación por hora que el backend guarda en `cronograma.slot_ocupacion`.
     * La escribe el trigger `onInscripcionContador` (repo web) ante cualquier alta, baja
     * o edición de inscripción, así que es la misma cuenta que usa el link público para
     * bloquear los horarios llenos.
     *
     * El rango sale del horario del propio taller; se ensancha si hay slots fuera de esa
     * ventana para no esconder a nadie que haya quedado agendado fuera de hora.
     */
    static func ocupacionPorHora(de item: CronogramaItem) -> [OcupacionHoraDato] {
        let slots = item.slot_ocupacion ?? [:]
        let horasConDatos = slots.keys.compactMap(Int.init)

        let apertura = hora(de: item.hora_inicio) ?? aperturaPorDefecto
        let cierre = hora(de: item.hora_fin) ?? cierrePorDefecto

        let desde = min(apertura, horasConDatos.min() ?? apertura)
        let hasta = max(cierre, horasConDatos.max() ?? cierre)
        guard desde <= hasta else { return [] }

        return (desde...hasta).map { hora in
            OcupacionHoraDato(
                hora: hora,
                horaString: "\(hora)",
                cantidad: slots[String(format: "%02d", hora)] ?? 0
            )
        }
    }

    /// "13:00" → 13
    private static func hora(de hhmm: String?) -> Int? {
        minutosDesdeMedianoche(from: hhmm).map { $0 / 60 }
    }

    /**
     * Helper para convertir "HH:mm" a un Int (minutos desde medianoche).
     * Ej: "14:30" → 870
     */
    static func minutosDesdeMedianoche(from hhmm: String?) -> Int? {
        guard let hhmm else { return nil }
        let components = hhmm.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return (components[0] * 60) + components[1]
    }
}
