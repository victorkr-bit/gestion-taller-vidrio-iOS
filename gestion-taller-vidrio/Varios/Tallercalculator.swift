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

    // MARK: - Cálculo de Ocupación por Hora (Rango Fijo 13–21)

    /**
     * Calcula la ocupación total por hora para un conjunto de inscripciones.
     * Se usa en `DashboardViewModel` para el gráfico de barras.
     * Siempre devuelve las 9 horas del rango fijo, aunque la ocupación sea 0.
     */
    static func calcularOcupacionPorHora(para inscripciones: [Inscripcion]) -> [OcupacionHoraDato] {
        let rangoFijo = 13...21

        // 1. Inicializar cubetas en 0 para el rango fijo
        var ocupacionPorHora: [Int: Int] = [:]
        for hora in rangoFijo {
            ocupacionPorHora[hora] = 0
        }

        // 2. Procesar inscripciones
        for inscripcion in inscripciones {
            guard let inicioMinutos = minutosDesdeMedianoche(from: inscripcion.horario_inicio) else { continue }
            let horaInicio = inicioMinutos / 60
            let cantidadTurnos = inscripcion.turnos ?? 1
            let minutosExtra = inicioMinutos % 60
            let horasAfectadas = minutosExtra > 0 ? cantidadTurnos + 1 : cantidadTurnos

            for i in 0..<horasAfectadas {
                let horaAfectada = horaInicio + i
                ocupacionPorHora[horaAfectada, default: 0] += 1
            }
        }

        // 3. Convertir a Array ordenado para el gráfico
        return rangoFijo.map { hora in
            OcupacionHoraDato(hora: hora, horaString: "\(hora)", cantidad: ocupacionPorHora[hora] ?? 0)
        }
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
