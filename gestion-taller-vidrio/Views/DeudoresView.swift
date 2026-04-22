import SwiftUI

struct DeudoresView: View {

    @ObservedObject var viewModel: DeudoresViewModel
    
    @State private var origenParaPagar: Origen?
    @State private var origenParaCondonar: Origen?
    @State private var showingCondonarAlert = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Espaciado.l) {
                    KpiCardView(
                        titulo: "Pedidos",
                        valor: viewModel.totalDeudaPedidos,
                        icon: "shippingbox.fill",
                        color: DesignSystem.Color.accion
                    )
                    KpiCardView(
                        titulo: "Inscripciones",
                        valor: viewModel.totalDeudaInscripciones,
                        icon: "graduationcap.fill",
                        color: DesignSystem.Color.pendiente
                    )
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar cliente o descripción...", text: $viewModel.searchText)
                }
                .padding(DesignSystem.Espaciado.s)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
                .padding(.horizontal)
                .padding(.top, 8)

            List {
                ForEach(viewModel.deudoresFiltrados) { deudor in
                    CardView {
                        GenericRowView(
                            titulo: deudor.nombreCliente,
                            subtitulo: deudor.descripcion,
                            infoSuperior: Formatters.date(deudor.fecha),
                            iconoSuperior: nil,
                            monto: deudor.montoAdeudado,
                            tags: {
                                var t = [TagConfig(text: deudor.tipo.rawValue.capitalized, color: deudor.tipo == .pedido ? DesignSystem.Color.accion : DesignSystem.Color.pendiente)]
                                if deudor.estaVencida {
                                    t.append(TagConfig(text: "Vencida", color: DesignSystem.Color.peligro))
                                }
                                return t
                            }()
                        )
                    }
                    .listRowSeparator(.hidden)
                    
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            self.origenParaPagar = deudor.origen
                        } label: {
                            Label("Registrar Pago", systemImage: "plus.circle.fill")
                        }
                        .tint(DesignSystem.Color.exito)
                    }
                    
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            self.origenParaCondonar = deudor.origen
                            self.showingCondonarAlert = true
                        } label: {
                            Label("Condonar", systemImage: "hand.thumbsup.fill")
                        }
                        .tint(DesignSystem.Color.neutro)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.isLoading && viewModel.deudores.isEmpty {
                    ProgressView("Cargando deudores...")
                } else if !viewModel.isLoading && viewModel.deudoresFiltrados.isEmpty {
                    EstadoVacioView(
                        icono: viewModel.deudores.isEmpty ? "checkmark.circle" : "magnifyingglass",
                        mensaje: viewModel.deudores.isEmpty
                            ? "¡No hay deudas pendientes!"
                            : "Sin resultados para \"\(viewModel.searchText)\"",
                        colorIcono: viewModel.deudores.isEmpty ? DesignSystem.Color.exito : Color.secondary
                    )
                }
            }
            } // VStack

            if viewModel.isLoading && !viewModel.deudores.isEmpty {
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radio.input))
            }
        }
        .navigationTitle("Deudores")
        .refreshable {
            viewModel.fetchDeudores()
        }
        .errorAlert($viewModel.errorMessage)
        .onAppear {
            viewModel.fetchDeudores()
        }
        
        .sheet(item: $origenParaPagar) { origen in
            NavigationStack {
                RegistrarPagoView(
                    origen: origen,
                    onSave: { (pago, origen) in
                        try await viewModel.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        
        .alert("¿Condonar Deuda?", isPresented: $showingCondonarAlert, presenting: origenParaCondonar) { origen in
            Button("Condonar Deuda", role: .destructive) {
                viewModel.condonarDeuda(origen: origen)
            }
            Button("Cancelar", role: .cancel) { }
        } message: { origen in
            Text("Estás a punto de setear la deuda de \(origen.clienteNombre) a $0, sin registrar un pago. Esta acción no se puede deshacer.")
        }
    }
}

