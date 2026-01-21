import SwiftUI

struct CajaView: View {
    
    @ObservedObject private var viewModel: CajaViewModel
    
    init(viewModel: CajaViewModel) {
        self.viewModel = viewModel
    }
    
    @State private var searchText = ""
    @State private var pagoToEdit: Pago?
    @State private var isCreatingVentaDirecta = false
    

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) { // 1. Contenedor Vertical Principal
                        
                        // 2. EL HEADER FIJO (Fuera de la lista)
                        TotalHeaderView(total: viewModel.totalFiltrado)
                        
                        // 3. LA LISTA (Ahora solo contiene datos)
                        List {
                            if viewModel.isLoading {
                                HStack {
                                    Spacer(); ProgressView("Cargando..."); Spacer()
                                }
                                .listRowSeparator(.hidden)
                                .padding(.top, 50)
                                
                            } else if viewModel.filteredAndSearchedPagos.isEmpty {
                                ContentUnavailableView(
                                    "No hay movimientos",
                                    systemImage: "list.bullet.clipboard",
                                    description: Text("Intenta cambiar el filtro.")
                                )
                                .listRowSeparator(.hidden)
                                
                            } else {
                                // Items
                                ForEach(viewModel.filteredAndSearchedPagos) { pago in
                                    CajaPagoRow(
                                        pago: pago,
                                        viewModel: viewModel,
                                        pagoToEdit: $pagoToEdit
                                    )
                                    // OPTIMIZACIÓN: Aplicar el ocultar separador AQUÍ o a la lista global
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    // El inset manual ayuda a que la Card no toque los bordes si usas .plain
                                }
                            }
                        }
                        .listStyle(.plain) // Mantenemos plain para que no agregue estilo extra
                        .scrollContentBackground(.hidden) // Opcional: limpia el fondo gris por defecto
                    }
                    .navigationTitle("Caja")
                    .navigationBarTitleDisplayMode(.large)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar...")
                    
                    .onChange(of: searchText) { _, nuevoTexto in
                // Antes llamabas a filtrarPedidos(...), ahora solo actualizas la propiedad
                        viewModel.searchText = nuevoTexto
                    }

            // TOOLBAR
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.isCreatingVentaDirecta = true
                    } label: {
                        Image(systemName: "cart.badge.plus")
                    }
                }
            }
            
            // Sheets y Alertas
            .sheet(isPresented: $isCreatingVentaDirecta) {
                NavigationStack { VentaDirectaFormView(viewModel: viewModel) }
            }
            .sheet(item: $pagoToEdit) { pago in
                NavigationStack { PagoFormView(viewModel: viewModel, pagoToEdit: pago) }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error desconocido.")
            })
        }
    }
}

// MARK: - Subvista del Header (Total)
// Extraída para mantener limpio el código principal
struct TotalHeaderView: View {
    let total: Double
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Total Filtrado:")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray))
                    .textCase(nil) // Evita que SwiftUI lo ponga en mayúsculas por defecto
                
                Spacer()
                
                Text(Formatters.money(total))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.blue)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.regularMaterial) // Fondo translúcido bonito
            
            Divider()
        }
        // Truco importante: Quitamos los insets por defecto del header de lista
        // para que ocupe todo el ancho de la pantalla.
        
    }
}

// MARK: - Subvista de Fila (Sin cambios)
private struct CajaPagoRow: View {
    let pago: Pago
    @ObservedObject var viewModel: CajaViewModel
    @Binding var pagoToEdit: Pago?
    
    var body: some View {
        CardView {
            GenericRowView(
                titulo: pago.cliente_nombre,
                subtitulo: pago.descripcion_origen,
                infoSuperior: Formatters.date(pago.fecha),
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


