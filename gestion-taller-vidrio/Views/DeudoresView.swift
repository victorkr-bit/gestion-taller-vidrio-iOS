import SwiftUI

struct DeudoresView: View {

    @ObservedObject var viewModel: DeudoresViewModel
    @EnvironmentObject var navigationManager: NavigationManager

    @State private var deudorSeleccionado: DeudorItem?

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
                        Button {
                            Task { await navigate(to: deudor) }
                        } label: {
                            CardView {
                                GenericRowView(
                                    titulo: deudor.nombreCliente,
                                    subtitulo: deudor.descripcion,
                                    infoSuperior: Formatters.date(deudor.fecha),
                                    iconoSuperior: nil,
                                    monto: deudor.montoAdeudado,
                                    tags: [TagConfig(
                                        text: deudor.tipo.rawValue.capitalized,
                                        color: deudor.tipo == .pedido ? DesignSystem.Color.accion : DesignSystem.Color.pendiente
                                    )]
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button {
                                deudorSeleccionado = deudor
                            } label: {
                                Label("Registrar pago", systemImage: "dollarsign.circle.fill")
                            }
                            .tint(DesignSystem.Color.exito)
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
                                ? "Sin cobros vencidos"
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Orden", selection: $viewModel.orden) {
                        Label("Monto (mayor a menor)", systemImage: "arrow.down.circle")
                            .tag(OrdenDeudores.montoDescendente)
                        Label("Fecha (más reciente)", systemImage: "calendar.badge.minus")
                            .tag(OrdenDeudores.fechaDescendente)
                        Label("Fecha (más antiguo)", systemImage: "calendar.badge.plus")
                            .tag(OrdenDeudores.fechaAscendente)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .refreshable {
            viewModel.fetchDeudores()
        }
        .errorAlert($viewModel.errorMessage)
        .onAppear {
            viewModel.fetchDeudores()
        }
        .sheet(item: $deudorSeleccionado) { deudor in
            NavigationStack {
                RegistrarPagoView(origen: deudor.origen, fechaInicial: deudor.fecha) { pago, origen, pagosSplit in
                    try await viewModel.registrarPago(pago: pago, origen: origen, pagosSplit: pagosSplit)
                }
            }
        }
    }

    private func navigate(to deudor: DeudorItem) async {
        switch deudor.origen {
        case .pedido:
            navigationManager.selectedTab = .pedidos
        case .inscripcion(let inscripcion):
            if let cronogramaId = inscripcion.cronogramaId,
               let item = await viewModel.fetchCronogramaItem(id: cronogramaId) {
                navigationManager.navigateToCourseDetail(item)
            } else {
                navigationManager.selectedTab = .cronograma
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DeudoresView(viewModel: PreviewContainer.shared.deudoresVM)
    }
    .environmentObject(NavigationManager())
}
#endif

