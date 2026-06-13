import SwiftUI
import Charts

struct FacturacionView: View {
    @ObservedObject var metricasVM: MetricasViewModel
    @ObservedObject var chartsVM: ChartsViewModel
    @ObservedObject var filter: FilterCoordinator
    @State private var showFiltro = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.xl) {
                ingresosPorTipoSection
                facturacionAnualSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Facturación")
        .background(Color(.systemGroupedBackground))
        .errorAlert($metricasVM.errorMessage)
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

    // MARK: - Ingresos por Tipo

    private var ingresosPorTipoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text("Ingresos por Tipo")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if metricasVM.datosGraficoPorTipo.isEmpty {
                Text("No hay ingresos en el período seleccionado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 14) {
                    ForEach(metricasVM.datosGraficoPorTipo) { dato in
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

    // MARK: - Facturación Mensual (13 meses, YtY)

    private var facturacionAnualSection: some View {
        let añoActual = Calendar.current.component(.year, from: Date())
        let datosOrdenados = chartsVM.facturacionAnual
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
}

#if DEBUG
#Preview {
    let c = PreviewContainer.shared
    NavigationStack {
        FacturacionView(metricasVM: c.metricasVM, chartsVM: c.chartsVM, filter: c.filterCoordinator)
    }
    .environmentObject(NavigationManager())
}
#endif
