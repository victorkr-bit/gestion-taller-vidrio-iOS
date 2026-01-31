import SwiftUI

struct CajaView: View {
    @ObservedObject var viewModel: CajaViewModel
    
    @State private var showVentaDirecta = false
    @State private var pagoAEditar: Pago? = nil
    
    // Formateador para el total
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_AR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Buscador y Total
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Buscar cliente, nota...", text: $viewModel.searchText)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                
                HStack {
                    Spacer()
                    Text("Total Filtrado:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currencyFormatter.string(from: NSNumber(value: viewModel.totalFiltrado)) ?? "$0")
                        .font(.title3)
                        .bold()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            // MARK: - Lista de Pagos
            if viewModel.isLoading {
                Spacer()
                ProgressView("Cargando movimientos...")
                Spacer()
            } else if viewModel.pagosFiltrados.isEmpty {
                Spacer()
                VStack(spacing: 15) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No hay movimientos")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.pagosFiltrados) { pago in
                        // Usamos la Row personalizada
                        CajaPagoRow(
                            pago: pago,
                            viewModel: viewModel,
                            pagoToEdit: $pagoAEditar
                        )
                        // Ajustes visuales para que la Card se vea bien en una lista
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Caja")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showVentaDirecta = true }) {
                    Label("Venta Directa", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showVentaDirecta) {
            NavigationStack {
                VentaDirectaFormView(viewModel: viewModel)
            }
        }
        .sheet(item: $pagoAEditar) { pago in
             NavigationStack {
                 PagoFormView(viewModel: viewModel, pagoToEdit: pago)
             }
        }
    }
}

// MARK: - Subvista de Fila (Restaurada)
private struct CajaPagoRow: View {
    let pago: Pago
    @ObservedObject var viewModel: CajaViewModel
    @Binding var pagoToEdit: Pago?
    
    var body: some View {
        CardView {
            GenericRowView(
                titulo: pago.cliente_nombre,
                subtitulo: pago.descripcion_origen,
                // Usamos el formateador nativo si no tienes tu clase Formatters a mano
                infoSuperior: pago.fecha.formatted(date: .numeric, time: .shortened),
                iconoSuperior: nil,
                monto: pago.monto,
                tags: [
                    TagConfig(text: pago.medio_de_pago.rawValue, color: .purple),
                    TagConfig(text: pago.tipo_venta.descripcion, color: .blue)
                ]
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.deletePago(pago)
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            
            Button {
                self.pagoToEdit = pago
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
