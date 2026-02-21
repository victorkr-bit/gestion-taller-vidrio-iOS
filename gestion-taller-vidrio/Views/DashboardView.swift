import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var deudoresVM: DeudoresViewModel

    // Inyectamos el Manager para poder cambiar de pestaña al hacer click
    @EnvironmentObject var navManager: NavigationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - Filtro de Fechas
                FiltroMesAñoView(desde: $viewModel.mesInicio, hasta: $viewModel.mesFin)
                
                // MARK: - Tarjetas de Resumen (KPIs)
                HStack(spacing: 15) {
                    Button {
                        navManager.selectedTab = .caja
                    } label: {
                        KpiCardView(
                            titulo: "Ingresos",
                            valor: viewModel.totalIngresosMes,
                            icon: "arrow.up.circle.fill",
                            color: .blue
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
                
                // MARK: - Próxima Actividad
                VStack(alignment: .leading, spacing: 10) {
                    Text("Próxima Actividad")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if let actividad = viewModel.proximaClase {
                        // 1. Tarjeta Clickeable
                        Button {
                            navManager.selectedTab = .cronograma
                            navManager.cronogramaPath.append(actividad)
                        } label: {
                            CardView {
                                GenericRowView(
                                    titulo: actividad.cursoNombre,
                                    subtitulo: nil, //actividad.cursoTipo.descripcion.uppercased(),
                                    infoSuperior: Formatters.date(actividad.fecha),
                                    infoSuperiorSecundaria: nil, //Formatters.time(actividad.fecha),
                                    iconoSuperior: "calendar",
                                    monto: nil,
                                    tags: [
                                        TagConfig(
                                            text: "Inscriptos: \(actividad.inscriptosReales)",
                                            color: .blue
                                        )
                                    ]
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // 2. Gráfico de Ocupación (Solo si es Taller y hay datos)
                        if actividad.cursoTipo == .taller && !viewModel.ocupacionTaller.isEmpty {
                            ocupacionChart
                        }
                        
                    } else {
                        // Estado Vacío
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
                    }
                }
                
                // MARK: - Gráfico de Ingresos por Tipo (REFACTORIZADO)
                VStack(alignment: .leading) {
                    Text("Ingresos por Tipo")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if viewModel.datosGraficoPorTipo.isEmpty {
                        Text("No hay ingresos en el período seleccionado")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        Chart {
                            ForEach(viewModel.datosGraficoPorTipo) { dato in
                                BarMark(
                                    x: .value("Monto", dato.monto),
                                    y: .value("Tipo", dato.tipo),
                                    height: .fixed(25)
                                )
                                .foregroundStyle(by: .value("Tipo", dato.tipo))
                                // 1. Nombre del Tipo ARRIBA de la barra
                                .annotation(position: .top, alignment: .leading) {
                                    Text(dato.tipo)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                }
                                // 2. Monto y Porcentaje al COSTADO
                                .annotation(position: .trailing) {
                                    Text("\(Formatters.money(dato.monto)) (\(dato.porcentaje)%)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        // Aumentamos altura para dar espacio a las etiquetas superiores
                        .frame(height: max(120, CGFloat(viewModel.datosGraficoPorTipo.count) * 55))
                        .chartForegroundStyleScale { TipoVenta.color(forDescripcion: $0) }
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden) // Ocultamos eje Y porque la etiqueta ya está arriba
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                }
                
                // MARK: - Detalle de Clases
                if viewModel.detalleClases.tieneContenido {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detalle de clases")
                            .font(.title2).fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            // TALLER — una sola fila
                            if let t = viewModel.detalleClases.taller {
                                DetalleHeaderRow(
                                    label: "Taller",
                                    color: TipoVenta.taller.color,
                                    resumen: "\(t.clases) \(t.clases == 1 ? "clase" : "clases") · \(t.alumnos) \(t.alumnos == 1 ? "alumno" : "alumnos")"
                                )
                                if !viewModel.detalleClases.presencial.isEmpty || !viewModel.detalleClases.online.isEmpty {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // PRESENCIAL — header + filas por curso
                            if !viewModel.detalleClases.presencial.isEmpty {
                                let totalCl = viewModel.detalleClases.presencial.reduce(0) { $0 + ($1.clases ?? 0) }
                                let totalAl = viewModel.detalleClases.presencial.reduce(0) { $0 + $1.alumnos }
                                DetalleHeaderRow(
                                    label: "Presencial",
                                    color: TipoVenta.presencial.color,
                                    resumen: "\(totalCl) \(totalCl == 1 ? "clase" : "clases") · \(totalAl) \(totalAl == 1 ? "alumno" : "alumnos")"
                                )
                                ForEach(viewModel.detalleClases.presencial) { curso in
                                    DetalleCursoRow(curso: curso)
                                    if curso.id != viewModel.detalleClases.presencial.last?.id {
                                        Divider().padding(.leading, 32)
                                    }
                                }
                                if !viewModel.detalleClases.online.isEmpty {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // ONLINE — header + filas por curso
                            if !viewModel.detalleClases.online.isEmpty {
                                let totalAl = viewModel.detalleClases.online.reduce(0) { $0 + $1.alumnos }
                                DetalleHeaderRow(
                                    label: "Online",
                                    color: TipoVenta.online.color,
                                    resumen: "\(totalAl) \(totalAl == 1 ? "alumno" : "alumnos")"
                                )
                                ForEach(viewModel.detalleClases.online) { curso in
                                    DetalleCursoRow(curso: curso)
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

                // MARK: - Tabla Facturación Anual
                VStack(alignment: .leading, spacing: 10) {
                    Text("Facturación últimos 12 meses")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(viewModel.facturacionAnual) { dato in
                            HStack {
                                Text(dato.label)
                                    .font(.subheadline)
                                if dato.esMesActual {
                                    Text("actual")
                                        .font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(4)
                                }
                                Spacer()
                                Text(dato.total > 0 ? Formatters.money(dato.total) : "—")
                                    .font(.subheadline)
                                    .fontWeight(dato.esMesActual ? .semibold : .regular)
                                    .foregroundStyle(dato.total > 0 ? .primary : .tertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(dato.esMesActual ? Color.blue.opacity(0.05) : Color(.systemBackground))

                            if dato.id != viewModel.facturacionAnual.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }

                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Inicio")
        .background(Color(.systemGroupedBackground))
        .errorAlert($viewModel.errorMessage)
    }
    
    // MARK: - Subvista del Gráfico de Ocupación
   
    private var ocupacionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ocupación estimada por hora")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Chart(viewModel.ocupacionTaller) { dato in
                BarMark(
                    x: .value("Hora", dato.horaString),
                    y: .value("Cantidad", dato.cantidad)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4) // Bordes redondeados superiores en las barras
                // Anotación numérica sobre la barra
                .annotation(position: .top) {
                    if dato.cantidad > 0 { // Solo mostrar número si hay alguien
                        Text("\(dato.cantidad)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 180) // Un poco más alto para apreciar las diferencias
            // Eje Y: Ocultamos etiquetas pero dejamos líneas de referencia suaves
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                }
            }
            // Eje X: Etiquetas fijas
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
            }
            // Escala Y: Para que siempre empiece de 0 y tenga aire arriba
            .chartYScale(domain: 0...( (viewModel.ocupacionTaller.map{$0.cantidad}.max() ?? 5) + 1 ))
            
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(.horizontal)
        }
    }
    
}

// MARK: - Subvistas Detalle de Clases

private struct DetalleHeaderRow: View {
    let label: String
    let color: Color
    let resumen: String
    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(color)
            Spacer()
            Text(resumen)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

private struct DetalleCursoRow: View {
    let curso: DetalleCurso
    var body: some View {
        HStack {
            Text(curso.nombre)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.leading, 16)
            Spacer()
            if let cl = curso.clases {
                Text("\(cl) \(cl == 1 ? "clase" : "clases") · \(curso.alumnos) \(curso.alumnos == 1 ? "alumno" : "alumnos")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(curso.alumnos) \(curso.alumnos == 1 ? "alumno" : "alumnos")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - Componentes Visuales (KPI)
struct KpiCardView: View {
    let titulo: String
    let valor: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(titulo).font(.caption).foregroundStyle(.secondary)
            }
            Text(Formatters.money(valor))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

