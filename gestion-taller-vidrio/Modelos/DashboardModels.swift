import Foundation

// MARK: - Detalle de clases

struct DetalleClases {
    var taller: DetalleTaller?
    var presencial: [DetalleCurso]
    var online: [DetalleCurso]
    var tieneContenido: Bool { taller != nil || !presencial.isEmpty || !online.isEmpty }
    var totalClases: Int {
        (taller?.clases ?? 0) + presencial.reduce(0) { $0 + ($1.clases ?? 0) }
    }
    var totalAlumnos: Int {
        (taller?.alumnos ?? 0) + presencial.reduce(0) { $0 + $1.alumnos } + online.reduce(0) { $0 + $1.alumnos }
    }
}

struct DetalleTaller {
    let clases: Int
    let alumnos: Int
}

struct DetalleCurso: Identifiable {
    var id: String { nombre }
    let nombre: String
    let clases: Int?  // nil para Online
    let alumnos: Int
}

// MARK: - Ocupación

struct OcupacionTallerItem: Identifiable {
    let id: String
    let titulo: String
    let datos: [OcupacionHoraDato]
}

// MARK: - Datos para gráficos

struct DatoGraficoTipo: Identifiable {
    let id = UUID()
    let tipo: String
    let monto: Double
    let porcentaje: Int
}

struct DatoMensual: Identifiable {
    var id: String { "\(año)-\(mes)" }
    let mes: Int
    let año: Int
    let total: Double

    var label: String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")
        return "\(cal.shortMonthSymbols[mes - 1].capitalized) \(año)"
    }

    var esMesActual: Bool {
        let c = Calendar.current, now = Date()
        return mes == c.component(.month, from: now) && año == c.component(.year, from: now)
    }

    var esAñoAnterior: Bool {
        año < Calendar.current.component(.year, from: Date())
    }
}

struct DatoMensualClases: Identifiable {
    var id: String { "\(año)-\(mes)" }
    let mes: Int
    let año: Int
    let clases: Int
    let alumnos: Int

    var label: String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")
        return "\(cal.shortMonthSymbols[mes - 1].capitalized) \(año)"
    }
}
