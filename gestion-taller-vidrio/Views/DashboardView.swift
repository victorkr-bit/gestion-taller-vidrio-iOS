import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var metricasVM: MetricasViewModel
    @ObservedObject var chartsVM: ChartsViewModel
    @ObservedObject var proximaActividadVM: ProximaActividadViewModel
    @ObservedObject var filter: FilterCoordinator
    @ObservedObject var deudoresVM: DeudoresViewModel
    @EnvironmentObject var navManager: NavigationManager

    @State private var showFiltro = false

    private var tendencia: Double {
        metricasVM.tendenciaPorcentaje(facturacionAnual: chartsVM.facturacionAnual)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.xl) {
                kpiGrid
                proximasActividadesSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Inicio")
        .background(Color(.systemGroupedBackground))
        .errorAlert($metricasVM.errorMessage)
        .errorAlert($proximaActividadVM.errorMessage)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            filter.sincronizarMesActualSiCambio()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showFiltro = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(filter.periodoLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignSystem.Color.accion)
                }
            }
        }
        .sheet(isPresented: $showFiltro) {
            NavigationStack {
                FiltroMesAñoView(desde: $filter.mesInicio, hasta: $filter.mesFin)
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

            if proximaActividadVM.proximasClases.isEmpty {
                EstadoVacioView(
                    icono: "calendar.badge.clock",
                    mensaje: "No hay actividades próximas.",
                    boton: ("Ir a Agenda", { navManager.selectedTab = .cronograma })
                )
            } else {
                HStack(spacing: 12) {
                    ForEach(proximaActividadVM.proximasClases) { actividad in
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

                if !proximaActividadVM.ocupacionesTaller.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Espaciado.s) {
                        Text("Ocupación por hora")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if proximaActividadVM.ocupacionesTaller.count == 2 {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(proximaActividadVM.ocupacionesTaller) { item in
                                    ocupacionChartPanel(item)
                                }
                            }
                            .padding(.horizontal)
                        } else if let item = proximaActividadVM.ocupacionesTaller.first {
                            ocupacionChartPanel(item)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - KPI Grid (Ingresos + A Cobrar / Deuda)

    private var ultimosMesesFacturacion: [DatoMensual] {
        Array(chartsVM.facturacionAnual.prefix(3).reversed())
    }

    private var kpiGrid: some View {
        VStack(spacing: DesignSystem.Espaciado.s) {
            HStack(alignment: .top, spacing: DesignSystem.Espaciado.l) {
                Button { navManager.selectedTab = .pagos } label: {
                    KpiCardView(
                        titulo: "Ingresos",
                        valor: metricasVM.totalIngresosMes,
                        icon: "arrow.up.circle.fill",
                        color: DesignSystem.Color.accion,
                        tendencia: tendencia != 0 ? tendencia : nil
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FacturacionView(metricasVM: metricasVM, chartsVM: chartsVM, filter: filter)
                } label: {
                    facturacionMiniChart
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DesignSystem.Espaciado.l) {
                KpiCardView(
                    titulo: "A Cobrar",
                    valor: metricasVM.totalMontoCobrar,
                    icon: "clock.fill",
                    color: DesignSystem.Color.pendiente
                )

                NavigationLink {
                    DeudoresView(viewModel: deudoresVM)
                } label: {
                    KpiCardView(
                        titulo: "Deuda vencida",
                        valor: metricasVM.totalDeudaReal,
                        icon: "exclamationmark.circle.fill",
                        color: DesignSystem.Color.peligro
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var maxFacturacionUltimosMeses: Double {
        ultimosMesesFacturacion.map(\.total).max() ?? 1
    }

    private var facturacionMiniChart: some View {
        Chart(ultimosMesesFacturacion) { dato in
            BarMark(
                x: .value("Mes", String(dato.label.prefix(3))),
                y: .value("Total", dato.total)
            )
            .foregroundStyle(dato.esMesActual ? DesignSystem.Color.accion : DesignSystem.Color.accion.opacity(0.5))
            .cornerRadius(DesignSystem.Radio.grafico)
            .annotation(position: .top) {
                if dato.total > 0 {
                    Text(Formatters.compactMoney(dato.total))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...(maxFacturacionUltimosMeses * 1.35))
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.system(size: 8))
            }
        }
        .padding(DesignSystem.Espaciado.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
        .sombraTarjeta(DesignSystem.Sombra.panel)
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
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.s) {
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

struct IngresoBarRow: View {
    let dato: DatoGraficoTipo

    private var barColor: Color { TipoVenta.color(forDescripcion: dato.tipo) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.xs) {
            HStack {
                HStack(spacing: DesignSystem.Espaciado.s) {
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

struct CategoriaHeaderRow: View {
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

struct CursoDetalleRow: View {
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

struct StatColumna: View {
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

struct TotalizadorRow: View {
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
        .padding(.horizontal, 30).padding(.vertical, 14)
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

#if DEBUG
#Preview {
    let c = PreviewContainer.shared
    NavigationStack {
        DashboardView(metricasVM: c.metricasVM, chartsVM: c.chartsVM,
                      proximaActividadVM: c.proximaActividadVM, filter: c.filterCoordinator,
                      deudoresVM: c.deudoresVM)
    }
    .environmentObject(NavigationManager())
}
#endif
