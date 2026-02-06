import SwiftUI

struct CajaView: View {
    @ObservedObject var viewModel: CajaViewModel
    
    @State private var showVentaDirecta = false
    @State private var pagoAEditar: Pago? = nil

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
                    //Spacer()
                    Text("Total Filtrado:")
                        .font(.callout)
                        .foregroundStyle(.primary)
                    
                    Text(Formatters.money(viewModel.totalFiltrado))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.blue)
                    Spacer()
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
                        CajaPagoRow(
                            pago: pago,
                            viewModel: viewModel,
                            pagoToEdit: $pagoAEditar
                        )
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
        .errorAlert($viewModel.errorMessage)
    }
}

// MARK: - Subvista de Fila
private struct CajaPagoRow: View {
    let pago: Pago
    @ObservedObject var viewModel: CajaViewModel
    @Binding var pagoToEdit: Pago?

    @State private var showDeleteAlert = false

    var body: some View {
        CardView {
            GenericRowView(
                titulo: pago.cliente_nombre,
                subtitulo: pago.descripcion_origen,
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
            Button {
                showDeleteAlert = true
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            .tint(.red)

            Button {
                self.pagoToEdit = pago
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("Eliminar Pago", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                viewModel.deletePago(pago)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminar el pago de \(Formatters.money(pago.monto)) de \(pago.cliente_nombre)? Esta acción no se puede deshacer.")
        }
    }
}
