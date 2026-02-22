import SwiftUI

struct PedidosView: View {

    @ObservedObject var viewModel: PedidosViewModel
    
    // Estados de UI
    @State private var isCreatingNew = false
    @State private var searchText = ""
    
    // Estado para Modales (Sheets)
    @State private var pedidoParaPagar: Pedido?
    @State private var pedidoParaEditar: Pedido?
    
    // Control de Expansión (Acordeón)
    @State private var expandedPedidoID: String?

    
    var body: some View {
        VStack(spacing: 0) {
            
            // 1. Filtros
            PedidosFiltersView(viewModel: viewModel)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGroupedBackground))
            
            Divider()
            
            // 2. Lista de Resultados
            ZStack {
                if viewModel.isLoading && viewModel.pedidosVisibles.isEmpty {
                    ProgressView("Cargando pedidos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.pedidosVisibles.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text(searchText.isEmpty
                             ? "No hay pedidos con los filtros seleccionados"
                             : "No hay pedidos que coincidan con \"\(searchText)\"")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.pedidosVisibles) { pedido in
                            PedidoRowView(
                                pedido: pedido,
                                viewModel: viewModel,
                                expandedPedidoID: $expandedPedidoID,
                                pedidoParaPagar: $pedidoParaPagar,
                                pedidoParaEditar: $pedidoParaEditar
                            )
                        }
                    }
                    .listStyle(.plain)
                    .animation(.default, value: searchText)
                    .animation(.default, value: viewModel.filtroPagoSeleccionado)
                    .animation(.default, value: viewModel.filtroEntregaSeleccionado)
                }
            }
        }
        .navigationTitle("Pedidos")
        .searchable(text: $searchText, prompt: "Buscar cliente, N° o descripción")
        .onChange(of: searchText) { _, nuevoTexto in
            viewModel.searchText = nuevoTexto
        }
        
        // Toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.isCreatingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                PedidoFormView(viewModel: viewModel.makePedidoFormViewModel())
            }
        }
        .sheet(item: $pedidoParaEditar) { pedido in
            NavigationStack {
                PedidoFormView(viewModel: viewModel.makePedidoFormViewModel(pedido: pedido))
            }
        }
        .sheet(item: $pedidoParaPagar) { pedido in
            NavigationStack {
                RegistrarPagoView(
                    origen: .pedido(pedido),
                    onSave: { (pago, origen) in
                        try await viewModel.registrarPago(pago: pago, origen: origen)
                    }
                )
            }
        }
        .errorAlert($viewModel.errorMessage)
        .refreshable {
            viewModel.startListeningOrders()
        }
        .onDisappear {
            expandedPedidoID = nil
            viewModel.cleanupPaymentListeners()
        }
    }
}

// MARK: - Row View (Acordeón + Swipes + ContextMenu)
struct PedidoRowView: View {
    let pedido: Pedido
    @ObservedObject var viewModel: PedidosViewModel
    
    @Binding var expandedPedidoID: String?
    @Binding var pedidoParaPagar: Pedido?
    @Binding var pedidoParaEditar: Pedido?

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            CardView {
                HStack {
                    // Contenido visual de la tarjeta
                    GenericRowView(
                        titulo: pedido.cliente_nombre,
                        subtitulo: "\(pedido.numero_pedido) - \(pedido.tipo.rawValue)",
                        infoSuperior: Formatters.date(pedido.fecha),
                        iconoSuperior: nil,
                        monto: pedido.presupuesto,
                        tags: [
                            TagConfig(text: pedido.estado_pago ? "Pagado" : "Debe \(Formatters.money(pedido.monto_adeudado))",
                                      color: pedido.estado_pago ? .green : .orange),
                            TagConfig(text: pedido.estado_entrega ? "Entregado" : "Pendiente",
                                      color: pedido.estado_entrega ? .gray : .purple)
                        ]
                    )
                    
                    Spacer()
                    
                    // Flechita giratoria
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expandedPedidoID == pedido.id ? 90 : 0))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                if expandedPedidoID == pedido.id {
                    // Colapsar
                    viewModel.stopListeningPagos(para: pedido)
                    expandedPedidoID = nil
                } else {
                    // Expandir
                    expandedPedidoID = pedido.id
                    viewModel.fetchPagos(para: pedido)
                }
            }
        }
        
        .contextMenu {
            Button {
                self.pedidoParaPagar = pedido
            } label: {
                Label("Registrar Pago", systemImage: "dollarsign.circle")
            }
            
            Button {
                self.pedidoParaEditar = pedido
            } label: {
                Label("Editar Pedido", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Eliminar Pedido", systemImage: "trash")
            }
        }

        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                self.pedidoParaPagar = pedido
            } label: {
                Label("Pagar", systemImage: "dollarsign.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("Borrar", systemImage: "trash.fill")
            }
            .tint(.red)

            Button {
                self.pedidoParaEditar = pedido
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("Eliminar Pedido", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                viewModel.deletePedido(pedido)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminar el pedido de \(pedido.cliente_nombre)? Esta acción no se puede deshacer.")
        }

        if expandedPedidoID == pedido.id {
            PagosPedidoListView(pedido: pedido, viewModel: viewModel)
        }
    }
}

// MARK: - Helper: Lista de Pagos para Pedidos
struct PagosPedidoListView: View {
    let pedido: Pedido
    @ObservedObject var viewModel: PedidosViewModel
    
    var body: some View {
        if let id = pedido.id, let pagos = viewModel.pagosPorPedido[id] {
            if pagos.isEmpty {
                Text("No hay pagos registrados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(pagos) { pago in
                    PagoRowView(pago: pago)
                        .padding(.leading, 20)
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                }
            }
        } else {
            // Estado de carga inicial
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            }
            .padding(8)
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Vista de Filtros
struct PedidosFiltersView: View {
    @ObservedObject var viewModel: PedidosViewModel
    
    // Estados locales para controlar qué diálogo se muestra
    @State private var showFiltroPago = false
    @State private var showFiltroEntrega = false
    
    var body: some View {
        HStack {
            // --- BOTÓN FILTRO PAGO ---
            HStack(spacing: 6) {
                Button {
                    showFiltroPago = true
                } label: {
                    FilterLabel(title: viewModel.filtroPagoSeleccionado.rawValue)
                }
                .confirmationDialog("Filtrar por Pago", isPresented: $showFiltroPago, titleVisibility: .visible) {
                    ForEach(PedidosViewModel.FiltroEstadoPago.allCases) { filtro in
                        Button(filtro.rawValue) {
                            viewModel.filtroPagoSeleccionado = filtro
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            }
            
            Divider().frame(height: 16)
            
            // --- BOTÓN FILTRO ENTREGA ---
            HStack(spacing: 6) {
                Button {
                    showFiltroEntrega = true
                } label: {
                    FilterLabel(title: viewModel.filtroEntregaSeleccionado.rawValue)
                }
                .confirmationDialog("Filtrar por Entrega", isPresented: $showFiltroEntrega, titleVisibility: .visible) {
                    ForEach(PedidosViewModel.FiltroEstadoEntrega.allCases) { filtro in
                        Button(filtro.rawValue) {
                            viewModel.filtroEntregaSeleccionado = filtro
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Etiqueta de Filtro
struct FilterLabel: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 80, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.footnote)
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

