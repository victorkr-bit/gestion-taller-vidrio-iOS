import SwiftUI

private let bsasCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
    cal.locale = Locale(identifier: "es_AR")
    return cal
}()

struct CalendarioAgendaView: View {
    let items: [CronogramaItem]
    @Environment(\.dismiss) private var dismiss

    private var diasOcupados: Set<DateComponents> {
        Set(items.map { item in
            let raw = bsasCalendar.dateComponents([.year, .month, .day], from: item.fecha)
            var comps = DateComponents()
            comps.year = raw.year
            comps.month = raw.month
            comps.day = raw.day
            return comps
        })
    }

    private var meses: [Date] {
        let ahora = Date()
        let inicioMes = bsasCalendar.date(from: bsasCalendar.dateComponents([.year, .month], from: ahora))!
        return [
            inicioMes,
            bsasCalendar.date(byAdding: .month, value: 1, to: inicioMes)!
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Espaciado.xl) {
                    ForEach(meses, id: \.self) { mes in
                        MesCalendarioView(mesDate: mes, diasOcupados: diasOcupados)
                    }
                }
                .padding(.horizontal, DesignSystem.Espaciado.l)
                .padding(.vertical, DesignSystem.Espaciado.m)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

struct MesCalendarioView: View {
    let mesDate: Date
    let diasOcupados: Set<DateComponents>

    private let diasSemana = ["L", "M", "X", "J", "V", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var diasEnMes: Int {
        bsasCalendar.range(of: .day, in: .month, for: mesDate)!.count
    }

    private var primerDiaSemana: Int {
        let weekday = bsasCalendar.component(.weekday, from: mesDate)
        return (weekday - 2 + 7) % 7  // 0 = lunes, ..., 6 = domingo
    }

    private var nombreMes: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_AR")
        fmt.dateFormat = "MMMM yyyy"
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        return fmt.string(from: mesDate).capitalized
    }

    private var año: Int { bsasCalendar.component(.year, from: mesDate) }
    private var mes: Int { bsasCalendar.component(.month, from: mesDate) }

    // nil = celda vacía de relleno, Int = número de día
    private var celdas: [Int?] {
        Array(repeating: nil, count: primerDiaSemana) + (1...diasEnMes).map { Optional($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text(nombreMes)
                .font(.headline)

            HStack(spacing: 0) {
                ForEach(diasSemana, id: \.self) { dia in
                    Text(dia)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: DesignSystem.Espaciado.xs) {
                ForEach(Array(celdas.enumerated()), id: \.offset) { _, dia in
                    if let dia {
                        DiaCalendarioView(dia: dia, ocupado: estaOcupado(dia: dia))
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(DesignSystem.Espaciado.l)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
    }

    private func estaOcupado(dia: Int) -> Bool {
        var comps = DateComponents()
        comps.year = año
        comps.month = mes
        comps.day = dia
        return diasOcupados.contains(comps)
    }
}

struct DiaCalendarioView: View {
    let dia: Int
    let ocupado: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dia)")
                .font(.callout)
                .fontWeight(ocupado ? .semibold : .regular)
                .foregroundStyle(ocupado ? DesignSystem.Color.accion : Color.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(ocupado ? DesignSystem.Color.accion.opacity(0.12) : .clear)
                )

            Circle()
                .fill(ocupado ? DesignSystem.Color.accion : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}
