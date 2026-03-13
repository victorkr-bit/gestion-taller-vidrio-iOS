import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var deudoresVM: DeudoresViewModel
    @EnvironmentObject var navManager: NavigationManager

    @State private var showFiltro = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                proximasActividadesSection
                kpiGrid
                ingresosPorTipoSection
                detalleClasesSection
                facturacionAnualSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Inicio")
        .background(Color(.systemGroupedBackground))
        .errorAlert($viewModel.errorMessage)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showFiltro = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(viewModel.periodoLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showFiltro) {
            NavigationStack {
                FiltroMesAñoView(desde: $viewModel.mesInicio, hasta: $viewModel.mesFin)
                    .padding()
                    .navigationTitle("Período")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { showFiltro = false }
                        }
                    }
            }
            .presentationDetents([.height(200)])
        }
    }

    // MARK: - Próximas Actividades

    private var proximasActividadesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Próximas Actividades")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if viewModel.proximasClases.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No hay actividades próximas.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.proximasClases) { actividad in
                        Button {
                            navManager.selectedTab = .cronograma
                            navManager.cronogramaPath.append(actividad)
                        } label: {
                            ProximaActividadCard(actividad: actividad)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                if !viewModel.ocupacionesTaller.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ocupación estimada por hora")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if viewModel.ocupacionesTaller.count == 2 {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(viewModel.ocupacionesTaller) { item in
                                    ocupacionChartPanel(item)
                                }
                            }
                            .padding(.horizontal)
                        } else if let item = viewModel.ocupacionesTaller.first {
                            ocupacionChartPanel(item)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - KPI Grid (Ingresos + Deuda)

    private var kpiGrid: some View {
        HStack(spacing: 15) {
            Button { navManager.selectedTab = .caja } label: {
                KpiCardView(
                    titulo: "Ingresos",
                    valor: viewModel.totalIngresosMes,
                    icon: "arrow.up.circle.fill",
                    color: .blue,
                    tendencia: viewModel.tendenciaPorcentaje != 0 ? viewModel.tendenciaPorcentaje : nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DeudoresView(viewModel: deudoresVM)
            } label: {
                KpiCardView(
                    titulo: "Deuda Total",
                    valor: viewModel.totalDeuda,
                    icon: "exclamationmark.circle.fill",
                    color: .red
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Ingresos por Tipo

    private var ingresosPorTipoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingresos por Tipo")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if viewModel.datosGraficoPorTipo.isEmpty {
                Text("No hay ingresos en el período seleccionado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 14) {
                    ForEach(viewModel.datosGraficoPorTipo) { dato in
                        IngresoBarRow(dato: dato)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Detalle de Clases del Período

    private var detalleClasesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detalle de Clases del Período")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: 0) {
                if !viewModel.detalleClases.tieneContenido {
                    Text("Sin clases en el período seleccionado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // TALLER — resumen único (sin desglose por curso)
                if let t = viewModel.detalleClases.taller {
                    TallerSummaryRow(clases: t.clases, alumnos: t.alumnos)
                    if !viewModel.detalleClases.presencial.isEmpty || !viewModel.detalleClases.online.isEmpty {
                        Divider().padding(.horizontal)
                    }
                }

                // PRESENCIAL — header + fila por curso
                if !viewModel.detalleClases.presencial.isEmpty {
                    let totalCl = viewModel.detalleClases.presencial.reduce(0) { $0 + ($1.clases ?? 0) }
                    let totalAl = viewModel.detalleClases.presencial.reduce(0) { $0 + $1.alumnos }
                    CategoriaHeaderRow(
                        label: "Presencial",
                        color: TipoVenta.presencial.color,
                        resumen: "\(totalCl) \(totalCl == 1 ? "clase" : "clases") · \(totalAl) \(totalAl == 1 ? "alumno" : "alumnos")",
                        icon: "studentdesk"
                    )
                    ForEach(viewModel.detalleClases.presencial) { curso in
                        CursoDetalleRow(curso: curso, mostrarClases: true)
                        if curso.id != viewModel.detalleClases.presencial.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                    if !viewModel.detalleClases.online.isEmpty {
                        Divider().padding(.horizontal)
                    }
                }

                // ONLINE — header + fila por curso
                if !viewModel.detalleClases.online.isEmpty {
                    let totalAl = viewModel.detalleClases.online.reduce(0) { $0 + $1.alumnos }
                    CategoriaHeaderRow(
                        label: "Online",
                        color: TipoVenta.online.color,
                        resumen: "\(totalAl) \(totalAl == 1 ? "alumno" : "alumnos")",
                        icon: "inset.filled.rectangle.and.person.filled"
                    )
                    ForEach(viewModel.detalleClases.online) { curso in
                        CursoDetalleRow(curso: curso, mostrarClases: false)
                        if curso.id != viewModel.detalleClases.online.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Facturación Mensual (13 meses, YtY)

    private var facturacionAnualSection: some View {
        let añoActual = Calendar.current.component(.year, from: Date())
        let datosOrdenados = viewModel.facturacionAnual
        let maxTotal = datosOrdenados.map { $0.total }.max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text("Facturación mensual")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if datosOrdenados.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart(datosOrdenados) { dato in
                        BarMark(
                            x: .value("Mes", dato.label),
                            y: .value("Total", dato.total)
                        )
                        .foregroundStyle(
                            dato.esMesActual ? Color.blue :
                            dato.esAñoAnterior ? Color.blue.opacity(0.25) : Color.blue.opacity(0.6)
                        )
                        .cornerRadius(5)
                        .annotation(position: .top, alignment: .center) {
                            if dato.total > 0 {
                                Text(Formatters.compactMoney(dato.total))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                        }
                    }
                    .frame(height: 210)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: 6)
                    .chartYScale(domain: 0...(maxTotal * 1.35))
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(Formatters.compactMoney(v)).font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let full = value.as(String.self) {
                                    Text(full.components(separatedBy: " ").first ?? full)
                                        .font(.caption2)
                                }
                            }
                        }
                    }

                    // Leyenda de años
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.25))
                                .frame(width: 16, height: 8)
                            Text(String(añoActual - 1)).font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.6))
                                .frame(width: 16, height: 8)
                            Text(String(añoActual)).font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.blue)
                                .frame(width: 16, height: 8)
                            Text("Mes actual").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Gráfico de Ocupación

    private func ocupacionChartPanel(_ item: OcupacionTallerItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Chart(item.datos) { dato in
                BarMark(
                    x: .value("Hora", dato.horaString),
                    y: .value("Cantidad", dato.cantidad)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if dato.cantidad > 0 {
                        Text("\(dato.cantidad)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s.components(separatedBy: ":").first ?? s)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...((item.datos.map { $0.cantidad }.max() ?? 5) + 1))
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Próxima Actividad Card

private struct ProximaActividadCard: View {
    let actividad: CronogramaItem

    private var diasHasta: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: actividad.fecha)).day ?? 0)
    }

    private var countdownText: String {
        switch diasHasta {
        case 0: return "Hoy"
        case 1: return "Mañana"
        default: return "En \(diasHasta) días"
        }
    }

    private var tipoColor: Color {
        switch actividad.cursoTipo {
        case .taller: return .green
        case .presencial: return .indigo
        case .online: return .cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(actividad.cursoTipo.descripcion.uppercased())
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(tipoColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tipoColor.opacity(0.15))
                    .cornerRadius(4)
                Spacer()
            }

            Text(actividad.cursoNombre)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "calendar").font(.caption2).foregroundStyle(.secondary)
                Text(Formatters.date(actividad.fecha)).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text(countdownText)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(diasHasta == 0 ? Color.orange : Color.blue)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "person.2.fill").font(.caption2)
                    Text("\(actividad.inscriptosReales)").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(height: 130)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Ingresos por Tipo Row

private struct IngresoBarRow: View {
    let dato: DatoGraficoTipo

    private var barColor: Color { TipoVenta.color(forDescripcion: dato.tipo) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: 10, height: 10)
                    Text(dato.tipo)
                        .font(.subheadline)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(Formatters.money(dato.monto))
                        .font(.subheadline).fontWeight(.semibold)
                    Text("· \(dato.porcentaje)%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(dato.porcentaje) / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Detalle de Clases Subvistas

private struct TallerSummaryRow: View {
    let clases: Int
    let alumnos: Int

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.caption)
                    .foregroundStyle(TipoVenta.taller.color)
                Text("Taller")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(TipoVenta.taller.color)
            }
            Spacer()
            Text("\(clases) \(clases == 1 ? "clase" : "clases") · \(alumnos) \(alumnos == 1 ? "alumno" : "alumnos")")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

private struct CategoriaHeaderRow: View {
    let label: String
    let color: Color
    let resumen: String
    let icon: String	

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(color)
            Spacer()
            Text(resumen)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(color.opacity(0.06))
    }
}

private struct CursoDetalleRow: View {
    let curso: DetalleCurso
    let mostrarClases: Bool

    var body: some View {
        HStack {
            Text(curso.nombre)
                .font(.subheadline)
                .padding(.leading, 32)
            Spacer()
            if mostrarClases, let cl = curso.clases {
                Text("\(cl) \(cl == 1 ? "clase" : "clases") · \(curso.alumnos) \(curso.alumnos == 1 ? "alumno" : "alumnos")")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("\(curso.alumnos) \(curso.alumnos == 1 ? "alumno" : "alumnos")")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - KPI Card

struct KpiCardView: View {
    let titulo: String
    let valor: Double
    let icon: String
    let color: Color
    var etiqueta: String? = nil
    var tendencia: Double? = nil

    private var tendenciaColor: Color {
        (tendencia ?? 0) >= 0 ? .green : .red
    }

    private var tendenciaLabel: String {
        guard let t = tendencia else { return "" }
        let signo = t >= 0 ? "↑" : "↓"
        return "\(signo) \(String(format: "%.1f", abs(t)))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(titulo).font(.caption).foregroundStyle(.secondary)
            }
            Text(etiqueta ?? Formatters.money(valor))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(tendencia != nil && tendencia != 0 ? tendenciaLabel : " ")
                .font(.caption2)
                .foregroundStyle(tendenciaColor)
                .opacity(tendencia != nil && tendencia != 0 ? 1 : 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
