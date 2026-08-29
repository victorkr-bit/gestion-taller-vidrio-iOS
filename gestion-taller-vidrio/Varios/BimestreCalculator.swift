import Foundation

struct DatoBimestral: Identifiable {
    let id: String
    let año: Int
    let bimestre: Int          // 0 = ene-feb, 1 = mar-abr, ... 5 = nov-dic
    let labelEje: String       // "sep-oct", sin año (entra en el ancho fijo del eje)
    let labelCompleto: String  // "sep-oct '25", para el tooltip
    let nuevos: Int
    let repiten: Int
}

/// Agrupa `DatoMensualRetencion` (ventana móvil de 12 meses) por bimestre calendario real
/// (ene-feb, mar-abr, may-jun, jul-ago, sep-oct, nov-dic), no por posición en la ventana —
/// así la agrupación no cambia según en qué mes esté parada la ventana móvil. En los bordes
/// de la ventana puede quedar un bimestre con un solo mes (ej. si la ventana arranca en
/// octubre, "sep-oct" solo trae octubre).
struct BimestreCalculator {
    static func agrupar(_ meses: [DatoMensualRetencion]) -> [DatoBimestral] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_AR")

        let grupos = Dictionary(grouping: meses) { dato in "\(dato.año)-\((dato.mes - 1) / 2)" }

        return grupos.values.map { grupo -> DatoBimestral in
            let ordenado = grupo.sorted { $0.mes < $1.mes }
            let primero = ordenado.first!
            let ultimo = ordenado.last!
            let bimestre = (primero.mes - 1) / 2
            let mesA = cal.shortMonthSymbols[primero.mes - 1].lowercased()
            let mesB = cal.shortMonthSymbols[ultimo.mes - 1].lowercased()
            let labelEje = primero.mes == ultimo.mes ? mesA : "\(mesA)-\(mesB)"
            return DatoBimestral(
                id: "\(primero.año)-\(bimestre)",
                año: primero.año,
                bimestre: bimestre,
                labelEje: labelEje,
                labelCompleto: "\(labelEje) '\(String(format: "%02d", primero.año % 100))",
                nuevos: ordenado.reduce(0) { $0 + $1.nuevos },
                repiten: ordenado.reduce(0) { $0 + $1.repiten }
            )
        }.sorted { ($0.año, $0.bimestre) < ($1.año, $1.bimestre) }
    }
}
