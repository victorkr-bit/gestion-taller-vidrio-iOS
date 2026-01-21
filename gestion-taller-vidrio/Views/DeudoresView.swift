import SwiftUI

struct DeudoresView: View {
    
    @StateObject private var viewModel = DeudoresViewModel()
    
    // Estado para el sheet de pago (Flujo 1)
    @State private var origenParaPagar: Origen?
    
    // Estado para el alert de condonación (Flujo 6)
    @State private var origenParaCondonar: Origen?
    @State private var showingCondonarAlert = false
    
    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.deudores) { deudor in
                    CardView {
                        GenericRowView(
                            titulo: deudor.nombreCliente,
                            subtitulo: deudor.descripcion,
                            infoSuperior: Formatters.date(deudor.fecha),
                            iconoSuperior: nil,
                            monto: deudor.montoAdeudado,
                            tags: [
                                TagConfig(text: deudor.tipo.rawValue.capitalized, color: deudor.tipo == .pedido ? .blue : .purple)
                            ]
                        )
                    }
                    .listRowSeparator(.hidden)
                    
                    // --- Swipe Action 1: Registrar Pago (Flujo 1) ---
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            self.origenParaPagar = deudor.origen
                        } label: {
                            Label("Registrar Pago", systemImage: "plus.circle.fill")
                        }
                        .tint(.green)
                    }
                    
                    // --- Swipe Action 2: Condonar Deuda (Flujo 6) ---
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            self.origenParaCondonar = deudor.origen
                            self.showingCondonarAlert = true
                        } label: {
                            Label("Condonar", systemImage: "hand.thumbsup.fill")
                        }
                        .tint(.gray)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.isLoading && viewModel.deudores.isEmpty {
                    ProgressView("Cargando deudores...")
                } else if !viewModel.isLoading && viewModel.deudores.isEmpty {
                    Text("¡No hay deudas pendientes!")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if viewModel.isLoading && !viewModel.deudores.isEmpty {
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Panel de Deudores")
        .refreshable {
            viewModel.fetchDeudores()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error.")
        })
        
        // --- Sheet para Flujo 1: Registrar Pago ---
        // Esto ahora funciona porque 'Origen' es Identifiable desde Helpers.swift
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
        
        // --- Alert para Flujo 6: Condonar Deuda ---
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



// --- INICIO DE LA CORRECCIÓN ---
// La extensión 'Origen: Identifiable' que estaba aquí se ELIMINÓ.
// (Esto soluciona los errores de "redeclaration")
/*
extension Origen: Identifiable {
    ... (ELIMINADO)
}
*/
// --- FIN DE LA CORRECCIÓN ---

