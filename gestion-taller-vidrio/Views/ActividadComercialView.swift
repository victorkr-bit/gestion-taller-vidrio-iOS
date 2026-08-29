import SwiftUI
import Charts

/// Azul-violeta dedicado a la serie "Repiten" — distinto de DesignSystem.Color.pendiente
/// (token compartido para "pendiente de entrega" en otras vistas, significado no relacionado).
private let colorRetencionRepite = Color.indigo

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

    // MARK: - Retención: Nuevos vs. Repiten (12 meses, barras apiladas, scrolleable)

    /// El detalle se dispara con `.chartGesture` + `SpatialTapGesture`, NO con `.chartXSelection`:
    /// esta última es drag-based y compite con el pan de `.chartScrollableAxes` (limitación conocida
    /// de Swift Charts — con scroll activo la selección mata el scroll). Un tap discreto sí convive
    /// con el pan, igual que una fila tocable dentro de una lista scrolleable.
    private var retencionSection: some View {
        // Invertido: mes actual a la izquierda; el chart arranca en el borde leading,
        // así que se ve lo más reciente y se scrollea a la derecha para ir al pasado.
        let datos = Array(chartsVM.retencionAnual.reversed())

        return VStack(alignment: .leading, spacing: DesignSystem.Espaciado.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alumnos Nuevos vs. Repiten (Presencial + Taller)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Últimos 12 meses · un alumno es \"nuevo\" solo la primera vez que se inscribe en cualquier actividad (incluye online, que no aparece en las barras)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            RetencionTooltip(dato: datos.first(where: { $0.labelCorto == mesRetencionSeleccionado }))
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.15), value: mesRetencionSeleccionado)

            if datos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(datos) { dato in
                            BarMark(
                                x: .value("Mes", dato.labelCorto),
                                y: .value("Alumnos", dato.nuevos)
                            )
                            .foregroundStyle(by: .value("Serie", "Nuevos"))
                        }
                        ForEach(datos) { dato in
                            BarMark(
                                x: .value("Mes", dato.labelCorto),
                                y: .value("Alumnos", dato.repiten)
                            )
                            .foregroundStyle(by: .value("Serie", "Repiten"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Nuevos": DesignSystem.Color.exito,
                        "Repiten": colorRetencionRepite
                    ])
                    .chartLegend(.hidden)
                    .frame(height: 200)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: 6)
                    .chartGesture { chart in
                        SpatialTapGesture().onEnded { v in
                            let tocado = chart.value(at: v.location, as: (String, Int).self)?.0
                            mesRetencionSeleccionado = (mesRetencionSeleccionado == tocado) ? nil : tocado
                        }
                    }
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
                            Circle().fill(colorRetencionRepite).frame(width: 8, height: 8)
                            Text("Repiten").font(.caption).foregroundStyle(.secondary)
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

/// Slot de altura fija: siempre ocupa el mismo lugar, tenga o no un mes seleccionado,
/// para que tocar una barra nunca mueva el resto del layout.
private struct RetencionTooltip: View {
    let dato: DatoMensualRetencion?

    var body: some View {
        Group {
            if let dato {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dato.labelCorto)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Circle().fill(DesignSystem.Color.exito).frame(width: 6, height: 6)
                        Text("Nuevos: \(dato.nuevos)").font(.caption2)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(colorRetencionRepite).frame(width: 6, height: 6)
                        Text("Repiten: \(dato.repiten)").font(.caption2)
                    }
                }
            } else {
                Text("Tocá una barra para ver el detalle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
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
