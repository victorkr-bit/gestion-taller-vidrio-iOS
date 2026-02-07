import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    // Inyectamos el Manager para poder cambiar de pestaña al hacer click
    @EnvironmentObject var navManager: NavigationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - Filtro de Fechas
                HStack {
                    Text("Desde:")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("Desde", selection: $viewModel.fechaInicio, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        //.environment(\.locale, Formatters.uiLocale)
                        .frame(maxWidth: .infinity)
                    Text("Hasta:")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    DatePicker("Hasta", selection: $viewModel.fechaFin, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        //.environment(\.locale, Formatters.uiLocale)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                // MARK: - Tarjetas de Resumen (KPIs)
                HStack(spacing: 15) {
                    KpiCardView(
                        titulo: "Ingresos",
                        valor: viewModel.totalIngresosMes,
                        icon: "arrow.up.circle.fill",
                        color: .blue
                    )
                    
                    KpiCardView(
                        titulo: "Deuda Total",
                        valor: viewModel.totalDeuda,
                        icon: "exclamationmark.circle.fill",
                        color: .red
                    )
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
                    
                    if datosGraficoPorTipo.isEmpty {
                        Text("No hay datos para mostrar")
                            .font(.caption)
                            .padding()
                    } else {
                        Chart {
                            ForEach(datosGraficoPorTipo) { dato in
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
                        .frame(height: max(120, CGFloat(datosGraficoPorTipo.count) * 55))
                        .chartForegroundStyleScale { tipoValue in colorParaTipo(tipoValue) }
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
    
    // MARK: - Lógica para Gráfico de Ingresos
    
    private func colorParaTipo(_ tipo: String) -> Color {
        switch tipo {
        case TipoVenta.piezas.descripcion: return Color.mint
        case TipoVenta.materiales.descripcion: return Color.orange
        case TipoVenta.joyeria.descripcion: return Color.purple
        case TipoVenta.taller.descripcion: return Color.green
        case TipoVenta.online.descripcion: return Color.cyan
        case TipoVenta.presencial.descripcion: return Color.indigo
        case TipoVenta.otros.descripcion: return Color.gray
        default: return Color.blue.opacity(0.5)
        }
    }
    
    // Struct auxiliar mejorada con porcentaje
    struct DatoGraficoTipo: Identifiable {
        let id = UUID()
        let tipo: String
        let monto: Double
        let porcentaje: Int
    }
    
    // Propiedad computada con cálculo de porcentaje
    var datosGraficoPorTipo: [DatoGraficoTipo] {
        let pagos = viewModel.pagosDelMes
        
        // 1. Calcular total global para sacar porcentajes
        let totalGlobal = pagos.reduce(0) { $0 + $1.monto }
        
        // 2. Agrupar
        let agrupados = Dictionary(grouping: pagos) { pago in
            pago.tipo_venta.descripcion
        }
        
        // 3. Mapear y calcular %
        return agrupados.map { (tipo, pagosGrupo) in
            let montoGrupo = pagosGrupo.reduce(0) { $0 + $1.monto }
            
            // Cálculo seguro del porcentaje (evitar división por cero)
            let porcentaje = totalGlobal > 0 ? Int((montoGrupo / totalGlobal) * 100) : 0
            
            return DatoGraficoTipo(
                tipo: tipo,
                monto: montoGrupo,
                porcentaje: porcentaje
            )
        }.sorted { $0.monto > $1.monto }
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

