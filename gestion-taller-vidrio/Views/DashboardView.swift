import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    // Inyectamos el Manager para poder cambiar de pestaña al hacer click
    @EnvironmentObject var navManager: NavigationManager
    
    // Formateador de moneda SIN DECIMALES (Punto 3)
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_AR")
        formatter.maximumFractionDigits = 0 // Sin decimales
        return formatter
    }()
    
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
                    Text("Hasta:")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    DatePicker("Hasta", selection: $viewModel.fechaFin, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                // MARK: - Tarjetas de Resumen (KPIs)
                // Punto 1: Mismo tamaño usando maxWidth: .infinity
                HStack(spacing: 15) {
                    kpiCard(
                        title: "Ingresos",
                        value: viewModel.totalIngresosMes,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                    
                    kpiCard(
                        title: "Deuda Total",
                        value: viewModel.totalDeuda,
                        icon: "exclamationmark.circle.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Próxima Actividad (Clickeable)
                VStack(alignment: .leading) {
                    Text("Próxima Actividad")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let clase = viewModel.proximaClase {
                        Button {
                            // Punto 4: Ir al Tab de Cronograma
                            navManager.selectedTab = .cronograma
                            navManager.cronogramaPath.append(clase)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(clase.cursoNombre)
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.primary)
                                    Text(clase.fecha.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(clase.cursoTipo.rawValue)
                                        .font(.caption)
                                        .padding(5)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(5)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(clase.inscriptosReales) inscriptos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .padding(.horizontal)
                        
                    } else {
                        HStack {
                            Spacer()
                            Text("No hay actividades programadas")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    }
                }
                
                // MARK: - Gráfico de Ingresos por Tipo
                VStack(alignment: .leading) {
                    Text("Ingresos por Tipo")
                        .font(.headline)
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
                                    y: .value("Tipo", dato.tipo)
                                )
                                .foregroundStyle(by: .value("Tipo", dato.tipo))
                                .annotation(position: .trailing) {
                                    Text(currencyFormatter.string(from: NSNumber(value: dato.monto)) ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 250)
                        .chartForegroundStyleScale { tipoValue in
                            colorParaTipo(tipoValue)
                        }
                        .chartLegend(.hidden)
                        // CAMBIO: Ocultamos completamente el Eje X (Líneas verticales y valores numéricos abajo)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        
                        // Estilos del contenedor
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
    }
    
    // MARK: - Componentes Auxiliares
    
    private func kpiCard(title: String, value: Double, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Punto 2: Sin wrapping, mismo linea
                Text(currencyFormatter.string(from: NSNumber(value: value)) ?? "$0")
                    .font(.title2)
                    .bold()
                    .lineLimit(1) // Fuerza una sola linea
                    .minimumScaleFactor(0.5) // Se achica si no entra
            }
            Spacer()
        }
        .padding()
        // Punto 1: Forzar expansión para igualar tamaños
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func colorParaTipo(_ tipo: String) -> Color {
            // Comparamos con las descripciones del enum TipoVenta
            switch tipo {
            case TipoVenta.piezas.descripcion:
                return Color.blue
            case TipoVenta.materiales.descripcion:
                return Color.orange
            case TipoVenta.joyeria.descripcion:
                return Color.purple
            case TipoVenta.taller.descripcion:
                return Color.green
            case TipoVenta.online.descripcion:
                return Color.cyan
            case TipoVenta.presencial.descripcion:
                return Color.indigo
            case TipoVenta.otros.descripcion:
                return Color.gray
            default:
                // Color por defecto si aparece un tipo nuevo no mapeado
                return Color.blue.opacity(0.5)
            }
        }
    
    // MARK: - Lógica para Gráfico "Ingresos por Tipo"
    
    struct DatoGraficoTipo: Identifiable {
        let id = UUID()
        let tipo: String
        let monto: Double
    }
    
    var datosGraficoPorTipo: [DatoGraficoTipo] {
        let pagos = viewModel.pagosDelMes
        
        // Agrupar por Tipo de Venta
        // (Nota: Asegúrate de que Pago tenga 'tipo_venta'. Si usas descripción, ajusta aquí)
        let agrupados = Dictionary(grouping: pagos) { pago in
            // Usamos rawValue o description del enum
            pago.tipo_venta.descripcion // o .rawValue
        }
        
        // Sumar y Ordenar (De Mayor a Menor monto)
        return agrupados.map { (tipo, pagos) in
            DatoGraficoTipo(tipo: tipo, monto: pagos.reduce(0) { $0 + $1.monto })
        }.sorted { $0.monto > $1.monto } // Orden descendente
    }
}
