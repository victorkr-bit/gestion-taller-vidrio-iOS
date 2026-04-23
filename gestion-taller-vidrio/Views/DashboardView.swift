import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var deudoresVM: DeudoresViewModel
    @EnvironmentObject var navManager: NavigationManager

    @State private var showFiltro = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.xl) {
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.sincronizarMesActualSiCambio()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showFiltro = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(viewModel.periodoLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignSystem.Color.accion)
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
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.s) {
            Text("Próximas Actividades")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if viewModel.proximasClases.isEmpty {
                EstadoVacioView(
                    icono: "calendar.badge.clock",
                    mensaje: "No hay actividades próximas.",
                    boton: ("Ir a Agenda", { navManager.selectedTab = .cronograma })
                )
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.proximasClases) { actividad in
                        Button {
                            navManager.navigateToCourseDetail(actividad)
                        } label: {
                            ProximaActividadCard(actividad: actividad)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                if !viewModel.ocupacionesTaller.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Espaciado.sm) {
                        Text("Ocupación por hora")
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
        HStack(spacing: DesignSystem.Espaciado.l) {
            Button { navManager.selectedTab = .pagos } label: {
                KpiCardView(
                    titulo: "Ingresos",
                    valor: viewModel.totalIngresosMes,
                    icon: "arrow.up.circle.fill",
                    color: DesignSystem.Color.accion,
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
                    color: DesignSystem.Color.peligro
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Ingresos por Tipo

    private var ingresosPorTipoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
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
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
                .sombraTarjeta(DesignSystem.Sombra.panel)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Detalle de Clases del Período

    private var detalleClasesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
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

                // TALLER — resumen único
                if let t = viewModel.detalleClases.taller {
                    let color = TipoVenta.taller.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Taller", color: color)
                        CursoDetalleRow(nombre: "Taller", clases: t.clases, alumnos: t.alumnos, color: color)
                            .padding(.horizontal, 16)
                    }
                }

                // PRESENCIAL — header + fila por curso
                if !viewModel.detalleClases.presencial.isEmpty {
                    let color = TipoVenta.presencial.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Presencial", color: color)
                        ForEach(viewModel.detalleClases.presencial) { curso in
                            CursoDetalleRow(nombre: curso.nombre, clases: curso.clases, alumnos: curso.alumnos, color: color)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                // ONLINE — header + fila por curso
                if !viewModel.detalleClases.online.isEmpty {
                    let color = TipoVenta.online.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Online", color: color)
                        ForEach(viewModel.detalleClases.online) { curso in
                            CursoDetalleRow(nombre: curso.nombre, clases: nil, alumnos: curso.alumnos, color: color)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if viewModel.detalleClases.tieneContenido {
                    Divider().padding(.horizontal).padding(.top, 4)
                    TotalizadorRow(
                        clases: viewModel.detalleClases.totalClases,
                        alumnos: viewModel.detalleClases.totalAlumnos
                    )
                }
            }
            .padding(.bottom, viewModel.detalleClases.tieneContenido ? 0 : 0)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
            .sombraTarjeta(DesignSystem.Sombra.panel)
            .padding(.horizontal)
        }
    }

    // MARK: - Facturación Mensual (13 meses, YtY)

    private var facturacionAnualSection: some View {
        let añoActual = Calendar.current.component(.year, from: Date())
        let datosOrdenados = viewModel.facturacionAnual
        let maxTotal = datosOrdenados.map { $0.total }.max() ?? 1

        return VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
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
                            dato.esMesActual ? DesignSystem.Color.accion :
                            dato.esAñoAnterior ? DesignSystem.Color.accion.opacity(0.25) : DesignSystem.Color.accion.opacity(0.6)
                        )
                        .cornerRadius(DesignSystem.Radio.grafico)
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
                                    Text(Formatters.compactMoney(v)).font(.caption)
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
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // Leyenda de años
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DesignSystem.Radio.indicador).fill(DesignSystem.Color.accion.opacity(0.25))
                                .frame(width: 16, height: 8)
                            Text(String(añoActual - 1)).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DesignSystem.Radio.indicador).fill(DesignSystem.Color.accion.opacity(0.6))
                                .frame(width: 16, height: 8)
                            Text(String(añoActual)).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DesignSystem.Radio.indicador).fill(DesignSystem.Color.accion)
                                .frame(width: 16, height: 8)
                            Text("Mes actual").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
                .sombraTarjeta(DesignSystem.Sombra.panel)
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
                .foregroundStyle(DesignSystem.Color.accion.gradient)
                .cornerRadius(DesignSystem.Radio.grafico)
                .annotation(position: .top) {
                    if dato.cantidad > 0 {
                        Text("\(dato.cantidad)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s.components(separatedBy: ":").first ?? s)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...((item.datos.map { $0.cantidad }.max() ?? 5) + 1))
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
            .sombraTarjeta(DesignSystem.Sombra.panel)
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
        actividad.cursoTipo.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.sm) {
            HStack {
                Text(actividad.cursoTipo.descripcion.uppercased())
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(tipoColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tipoColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.grafico))
                Spacer()
            }

            Text(actividad.cursoNombre)
                .font(.subheadline).fontWeight(.semibold)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "calendar").font(.caption2).foregroundStyle(.secondary)
                Text(Formatters.date(actividad.fecha)).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text(countdownText)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(diasHasta == 0 ? DesignSystem.Color.alerta : DesignSystem.Color.accion)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "person.2.fill").font(.caption2)
                    Text("\(actividad.inscriptosReales)").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(DesignSystem.Espaciado.m)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
        .sombraTarjeta(DesignSystem.Sombra.actividad)
    }
}

// MARK: - Ingresos por Tipo Row

private struct IngresoBarRow: View {
    let dato: DatoGraficoTipo

    private var barColor: Color { TipoVenta.color(forDescripcion: dato.tipo) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.xs) {
            HStack {
                HStack(spacing: DesignSystem.Espaciado.sm) {
                    RoundedRectangle(cornerRadius: DesignSystem.Radio.indicador)
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
                    RoundedRectangle(cornerRadius: DesignSystem.Radio.grafico)
                        .fill(barColor.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: DesignSystem.Radio.grafico)
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(dato.porcentaje) / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Detalle de Clases Subvistas

private struct CategoriaHeaderRow: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 2)
    }
}

private struct CursoDetalleRow: View {
    let nombre: String
    let clases: Int?
    let alumnos: Int
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(nombre)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let cl = clases {
                StatColumna(valor: cl, etiqueta: "CLASES", color: color)
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(width: 1, height: 32)
                    .padding(.horizontal, 12)
            }
            StatColumna(valor: alumnos, etiqueta: "ALUMNOS", color: color)
        }
        .padding(14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatColumna: View {
    let valor: Int
    let etiqueta: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(valor)")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(color)
            Text(etiqueta)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color.opacity(0.65))
        }
        .frame(minWidth: 48)
    }
}

private struct TotalizadorRow: View {
    let clases: Int
    let alumnos: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("Total del período")
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatColumna(valor: clases, etiqueta: "CLASES", color: .primary)
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 1, height: 32)
                .padding(.horizontal, 12)
            StatColumna(valor: alumnos, etiqueta: "ALUMNOS", color: .primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
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
        (tendencia ?? 0) >= 0 ? DesignSystem.Color.exito : DesignSystem.Color.peligro
    }

    private var tendenciaLabel: String {
        guard let t = tendencia else { return "" }
        let signo = t >= 0 ? "↑" : "↓"
        return "\(signo) \(String(format: "%.1f", abs(t)))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.s) {
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
        .sombraTarjeta(DesignSystem.Sombra.panel)
    }
}
