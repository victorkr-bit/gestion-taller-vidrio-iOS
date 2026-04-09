import SwiftUI

struct PagosView: View {
    @ObservedObject var viewModel: PagosViewModel
    
    @State private var showVentaDirecta = false
    @State private var pagoAEditar: Pago? = nil
    @State private var showFiltro = false

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Buscador y Total
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar cliente, nota...", text: $viewModel.searchText)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))

                HStack {
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
                EstadoVacioView(
                    icono: "tray",
                    mensaje: viewModel.searchText.isEmpty
                        ? "No hay movimientos en el período seleccionado"
                        : "No hay movimientos que coincidan con \"\(viewModel.searchText)\""
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.pagosFiltrados) { pago in
                        PagosRow(
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
        .navigationTitle("Pagos")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.sincronizarMesActualSiCambio()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showFiltro = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(viewModel.periodoLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showVentaDirecta = true }) {
                    Label("Venta Directa", systemImage: "plus")
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
private struct PagosRow: View {
    let pago: Pago
    @ObservedObject var viewModel: PagosViewModel
    @Binding var pagoToEdit: Pago?

    @State private var showDeleteAlert = false

    var body: some View {
        CardView {
            GenericRowView(
                titulo: pago.cliente_nombre,
                subtitulo: pago.descripcion_origen,
                infoSuperior: Formatters.date(pago.fecha),
                infoSuperiorSecundaria: Formatters.time(pago.fecha),
                iconoSuperior: nil,
                monto: pago.monto,
                tags: [
                    TagConfig(text: pago.medio_de_pago.rawValue, color: .purple),
                    TagConfig(text: pago.tipo_venta.descripcion, color: .blue)
                ]
            )
        }
        .contextMenu {
            Button {
                self.pagoToEdit = pago
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
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
