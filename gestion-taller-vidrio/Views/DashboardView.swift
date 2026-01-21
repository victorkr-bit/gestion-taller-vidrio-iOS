import SwiftUI
import Charts

struct DashboardView: View {
    
    @ObservedObject private var viewModel: DashboardViewModel
        @AppStorage("isDarkMode") private var isDarkMode = true
        
        init(viewModel: DashboardViewModel) {
            self.viewModel = viewModel
        }
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // --- Filtros de Fecha (Con Locale corregido) ---
                    HStack(spacing: 8) {
                        Text("Desde:")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        DatePicker("Desde", selection: $viewModel.fechaInicio, displayedComponents: .date)
                            .labelsHidden()
                            .scaleEffect(0.8)
                            .environment(\.locale, Formatters.uiLocale) // <--- CORRECCIÓN 1
                            .frame(maxWidth: .infinity)
                        
                        Text("Hasta:")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        DatePicker("Hasta", selection: $viewModel.fechaFin, displayedComponents: .date)
                            .labelsHidden()
                            .scaleEffect(0.8)
                            .environment(\.locale, Formatters.uiLocale) // <--- CORRECCIÓN 2
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // 1. KPIs
                    kpiSection
                    
                    // 2. Próxima Actividad
                    proximoTallerSection
                    
                    // 3. Gráfico de Torta
                    ingresosChart
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { isDarkMode.toggle() }
                    } label: {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .foregroundStyle(isDarkMode ? .yellow : .primary)
                    }
                }
            }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error.")
        })
    }
    
    // MARK: - Sub-vistas
    
    private var kpiSection: some View {
        HStack {
            KPICard(titulo: "Ingresos (neto)", valor: viewModel.totalIngresos, color: .blue)
            KPICard(titulo: "Deuda Total", valor: viewModel.totalDeuda, color: .orange)
        }
        .padding(.horizontal)
    }
    
    private var ingresosChart: some View {
            VStack(alignment: .leading) {
                Text("Ingresos por Tipo")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                if viewModel.ingresosUI.isEmpty {
                    Text("No hay ingresos en este período.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(height: 150, alignment: .center)
                } else {
                    Chart(viewModel.ingresosUI) { item in
                        BarMark(
                            x: .value("Monto", item.rawMonto),
                            y: .value("Tipo", item.tipo)
                        )
                        // Nota: Si 'item.color' es un Enum propio, necesitas una función que convierta Enum -> Color de SwiftUI
                        // Asumiremos que DashboardView tiene esa función auxiliar 'color(for:)'
                        .foregroundStyle(color(for: item.color))
                        .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                            Text("\(item.montoFormateado) \(item.porcentajeFormateado)")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartYScale(domain: viewModel.ingresosUI.map { $0.tipo })
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(viewModel.ingresosUI.count) * 44.0)
                    .padding(.horizontal)
                    .padding(.trailing, 100)
                }
            }
        }
    
    private var proximoTallerSection: some View {
            VStack(alignment: .leading) {
                Text("Próxima Actividad")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                if let actividad = viewModel.proximaActividad {
                    // CORRECCIÓN 3: Usar GenericRowView para consistencia
                    CardView {
                        GenericRowView(
                            titulo: actividad.cursoNombre,
                            subtitulo: "Inscriptos: \(viewModel.inscripcionesProximaActividad.count)",
                            infoSuperior: Formatters.date(actividad.fecha),
                            iconoSuperior: "calendar",
                            monto: nil, // Opcional, o actividad.precio_curso
                            tags: []
                        )
                    }
                    .padding(.horizontal)
                    
                    if actividad.cursoTipo == .taller && !viewModel.ocupacionTaller.isEmpty {
                        ocupacionChart // (Tu vista de gráfico existente)
                    }
                } else {
                    Text("No hay actividades próximas.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    
    private var ocupacionChart: some View {
               VStack(alignment: .leading) {
                   Text("Ocupación del Taller")
                       .font(.subheadline)
                       .fontWeight(.semibold)
                       .padding(.horizontal)
               
                   Chart(viewModel.ocupacionTaller) { dato in
                       BarMark(
                           x: .value("Hora", dato.horaString),
                           y: .value("Cantidad", dato.cantidad)
                       )
                       .foregroundStyle(Color.blue.gradient)
                   }
                   .frame(height: 150)
                   .padding()
               }
           }
    }
    
    private func color(for tipo: TipoVenta) -> Color {
        switch tipo {
        case .taller: return .blue
        case .piezas: return .green
        case .online: return .purple
        case .presencial: return .orange
        case .materiales: return .cyan
        case .joyeria: return .mint
        case .otros: return .gray
        }
    }


// Helper View
struct KPICard: View {
    let titulo: String
    let valor: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Formatters.money(valor))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // USO DE COLOR SEMÁNTICO DE SISTEMA PARA QUE CAMBIE AUTOMÁTICAMENTE
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
