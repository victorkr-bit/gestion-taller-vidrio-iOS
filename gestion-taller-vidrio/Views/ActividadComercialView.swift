import SwiftUI
import Charts

struct ActividadComercialView: View {
    @ObservedObject var chartsVM: ChartsViewModel
    @ObservedObject var filter: FilterCoordinator
    @State private var showFiltro = false
    @State private var mesRetencionSeleccionado: String?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.xl) {
                detalleClasesSection
                retencionSection
                evolucionMensualSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Actividad")
        .background(Color(.systemGroupedBackground))
        .errorAlert($chartsVM.errorMessage)
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

    // MARK: - Retención: Nuevos vs. Repiten (12 meses agrupados en 6 bimestres, barras apiladas)

    private var retencionSection: some View {
        let datos = BimestreCalculator.agrupar(chartsVM.retencionAnual).reversed()

        return VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alumnos Nuevos vs. Repiten (Presencial + Taller)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Últimos 12 meses (agrupados por bimestre) · un alumno es \"nuevo\" solo la primera vez que se inscribe en cualquier actividad (incluye online, que no aparece en las barras)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if datos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(datos) { dato in
                            BarMark(
                                x: .value("Bimestre", dato.labelEje),
                                y: .value("Alumnos", dato.nuevos)
                            )
                            .foregroundStyle(by: .value("Serie", "Nuevos"))
                        }
                        ForEach(datos) { dato in
                            BarMark(
                                x: .value("Bimestre", dato.labelEje),
                                y: .value("Alumnos", dato.repiten)
                            )
                            .foregroundStyle(by: .value("Serie", "Repiten"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Nuevos": DesignSystem.Color.exito,
                        "Repiten": DesignSystem.Color.pendiente
                    ])
                    .chartLegend(.hidden)
                    .frame(height: 200)
                    .chartXSelection(value: $mesRetencionSeleccionado)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label).font(.caption2)
                                }
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle().fill(DesignSystem.Color.exito).frame(width: 8, height: 8)
                            Text("Nuevos").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(DesignSystem.Color.pendiente).frame(width: 8, height: 8)
                            Text("Repiten").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if let sel = mesRetencionSeleccionado,
                       let dato = datos.first(where: { $0.labelEje == sel }) {
                        RetencionTooltip(label: dato.labelCompleto, nuevos: dato.nuevos, repiten: dato.repiten)
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


    // MARK: - Evolución Mensual (12 meses, doble eje Y)

    private var evolucionMensualSection: some View {
        let datos = chartsVM.clasesAnuales
        let maxClases = max(1, datos.map(\.clases).max() ?? 1)
        let maxAlumnos = max(1, datos.map(\.alumnos).max() ?? 1)

        return VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text("Evolución mensual")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if datos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(datos) { dato in
                            LineMark(
                                x: .value("Mes", dato.label),
                                y: .value("Clases", Double(dato.clases) / Double(maxClases)),
                                series: .value("Serie", "Clases")
                            )
                            .foregroundStyle(Color.blue)
                            .symbol(.circle)
                            .interpolationMethod(.catmullRom)
                        }
                        ForEach(datos) { dato in
                            LineMark(
                                x: .value("Mes", dato.label),
                                y: .value("Alumnos", Double(dato.alumnos) / Double(maxAlumnos)),
                                series: .value("Serie", "Alumnos")
                            )
                            .foregroundStyle(Color.orange)
                            .symbol(.square)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 200)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: 8)
                    .chartYScale(domain: 0...1.15)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
                            AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                            AxisTick()
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text("\(Int((d * Double(maxClases)).rounded()))")
                                        .font(.caption)
                                        .foregroundStyle(Color.blue.opacity(0.8))
                                }
                            }
                        }
                        AxisMarks(position: .trailing, values: [0.0, 0.5, 1.0]) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text("\(Int((d * Double(maxAlumnos)).rounded()))")
                                        .font(.caption)
                                        .foregroundStyle(Color.orange.opacity(0.8))
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
                        HStack(spacing: 6) {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                            Text("Clases").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 8, height: 8)
                            Text("Alumnos").font(.caption).foregroundStyle(.secondary)
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

    // MARK: - Detalle de Clases del Período

    private var detalleClasesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            Text("Detalle de Clases del Período")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: 0) {
                if !chartsVM.detalleClases.tieneContenido {
                    Text("Sin clases en el período seleccionado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let t = chartsVM.detalleClases.taller {
                    let color = TipoVenta.taller.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Taller", color: color)
                        CursoDetalleRow(nombre: "Taller", clases: t.clases, alumnos: t.alumnos, color: color)
                            .padding(.horizontal, 16)
                    }
                }

                if !chartsVM.detalleClases.presencial.isEmpty {
                    let color = TipoVenta.presencial.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Presencial", color: color)
                        ForEach(chartsVM.detalleClases.presencial) { curso in
                            CursoDetalleRow(nombre: curso.nombre, clases: curso.clases, alumnos: curso.alumnos, color: color)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if !chartsVM.detalleClases.online.isEmpty {
                    let color = TipoVenta.online.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Online", color: color)
                        ForEach(chartsVM.detalleClases.online) { curso in
                            CursoDetalleRow(nombre: curso.nombre, clases: nil, alumnos: curso.alumnos, color: color)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if chartsVM.detalleClases.tieneContenido {
                    Divider().padding(.horizontal).padding(.top, 4)
                    TotalizadorRow(
                        clases: chartsVM.detalleClases.totalClases,
                        alumnos: chartsVM.detalleClases.totalAlumnos
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
            .sombraTarjeta(DesignSystem.Sombra.panel)
            .padding(.horizontal)
        }
    }
}

private struct RetencionTooltip: View {
    let label: String
    let nuevos: Int
    let repiten: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Circle().fill(DesignSystem.Color.exito).frame(width: 6, height: 6)
                Text("Nuevos: \(nuevos)").font(.caption2)
            }
            HStack(spacing: 5) {
                Circle().fill(DesignSystem.Color.pendiente).frame(width: 6, height: 6)
                Text("Repiten: \(repiten)").font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.etiqueta))
        .sombraTarjeta(DesignSystem.Sombra.panel)
    }
}

#if DEBUG
#Preview {
    let c = PreviewContainer.shared
    NavigationStack {
        ActividadComercialView(chartsVM: c.chartsVM, filter: c.filterCoordinator)
    }
    .environmentObject(NavigationManager())
}
#endif
