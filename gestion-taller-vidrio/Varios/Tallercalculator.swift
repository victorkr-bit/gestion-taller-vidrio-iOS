import Foundation

// Tarea 5.2: Utilidad de Cálculo [cite: 94, 232]
// Contiene la lógica de negocio para la superposición de rangos de tiempo.

/// Struct de datos para el gráfico de barras del Dashboard.
struct OcupacionHoraDato: Identifiable {
    var id: Int { hora }
    let hora: Int // La hora (ej: 9, 10, 11)
    let horaString: String // "9:00"
    var cantidad: Int
}

struct TallerCalculator {
    
    // MARK: - Tarea 5.3: Cálculo de Ocupación por Alumno
    
    /**
     * Calcula la ocupación para un alumno específico, comparándolo contra la lista.
     * La lógica es: "cuántos alumnos (B, C, D...) se superponen con la hora de inicio del alumno A"[cite: 96, 371].
     * Se usará en `CronogramaViewModel`.
     */
    static func calcularOcupacion(para alumno: Inscripcion, enLista: [Inscripcion]) -> Int {
        
        // 1. Obtener el inicio del alumno principal (A) en minutos.
        guard let inicioA = minutosDesdeMedianoche(from: alumno.horario_inicio) else {
            return 0 // No se puede calcular si el alumno no tiene hora
        }
        
        var ocupacion = 0
        
        // 2. Iterar sobre todos (incluyéndose a sí mismo)
        for otroAlumno in enLista {
            
            // 3. Obtener el rango del "otro" alumno (B)
            guard let inicioB = minutosDesdeMedianoche(from: otroAlumno.horario_inicio),
                  let turnosB = otroAlumno.turnos else {
                continue // Ignorar alumnos sin datos
            }
            
            // Calculamos el fin del rango (ej: 14:00 + 2 turnos = 16:00, el rango es [840, 960) )
            let finB = inicioB + (turnosB * 60)
            
            // 4. Lógica de superposición: (B.inicio <= A.inicio) Y (B.fin > A.inicio)
            // ¿El rango del alumno B [inicioB, finB) contiene el instante A.inicio?
            if (inicioB <= inicioA) && (finB > inicioA) {
                ocupacion += 1
            }
        }
        return ocupacion
    }
    
    // MARK: - Tarea 5.1: Cálculo de Ocupación por Hora
    
    /**
     * Calcula la ocupación total por hora para un conjunto de inscripciones.
     * Se usará en `DashboardViewModel` para el gráfico de barras.
     * Devuelve solo las horas donde la ocupación es > 0.
     */
    // MARK: - Tarea 5.1: Cálculo de Ocupación por Hora (Rango Fijo 13–21)

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

                for i in 0..<cantidadTurnos {
                    let horaAfectada = horaInicio + i
                    if ocupacionPorHora[horaAfectada] != nil {
                        ocupacionPorHora[horaAfectada]! += 1
                    }
                }
            }

            // 3. Convertir a Array ordenado para el gráfico
            return rangoFijo.map { hora in
                OcupacionHoraDato(hora: hora, horaString: "\(hora)", cantidad: ocupacionPorHora[hora] ?? 0)
            }
        }

    /**
     * Helper para convertir "HH:mm" a un Int (minutos desde medianoche).
     * Ej: "14:30" -> 870
     */
    static func minutosDesdeMedianoche(from hhmm: String?) -> Int? {
        guard let hhmm = hhmm else { return nil }
        let components = hhmm.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return (components[0] * 60) + components[1]
    }
}
