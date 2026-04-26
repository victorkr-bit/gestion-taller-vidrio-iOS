import SwiftUI
import Charts

struct ActividadComercialView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showFiltro = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Espaciado.xl) {
                evolucionMensualSection
                detalleClasesSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Actividad")
        .background(Color(.systemGroupedBackground))
        .errorAlert($viewModel.errorMessage)
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

    // MARK: - Evolución Mensual (12 meses, doble eje Y)

    private var evolucionMensualSection: some View {
        let datos = viewModel.clasesAnuales
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
                if !viewModel.detalleClases.tieneContenido {
                    Text("Sin clases en el período seleccionado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let t = viewModel.detalleClases.taller {
                    let color = TipoVenta.taller.color
                    VStack(spacing: 6) {
                        CategoriaHeaderRow(label: "Taller", color: color)
                        CursoDetalleRow(nombre: "Taller", clases: t.clases, alumnos: t.alumnos, color: color)
                            .padding(.horizontal, 16)
                    }
                }

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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.tarjeta))
            .sombraTarjeta(DesignSystem.Sombra.panel)
            .padding(.horizontal)
        }
    }
}
