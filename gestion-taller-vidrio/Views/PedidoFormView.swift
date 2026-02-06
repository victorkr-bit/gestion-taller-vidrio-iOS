import SwiftUI

struct PedidoFormView: View {
    // Usamos el NUEVO ViewModel específico para formularios
    @StateObject var viewModel: PedidoFormViewModel
    
    @Environment(\.dismiss) var dismiss
    
    // Estado local para búsqueda de contactos
    @State private var contactos: [Contacto] = []
    
    // Estado intermedio para el input manual del presupuesto (Sanitización UI)
    @State private var presupuestoInput: String = ""
    
    
    var body: some View {
        Form {
            // -----------------------------------------------------------
            // SECCIÓN 1: CLIENTE
            // -----------------------------------------------------------
            Section("Datos del Cliente") {
                if !viewModel.isEditing {
                    // MODO NUEVO: Selector navegable
                    NavigationLink {
                        SelectorContactoView(
                            contactos: contactos,
                            selectedID: $viewModel.clienteId,
                            selectedNombre: $viewModel.clienteNombre
                        )
                    } label: {
                        HStack {
                            Text("Cliente*")
                            Spacer()
                            if viewModel.clienteId.isEmpty {
                                Text("Seleccionar")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(viewModel.clienteNombre)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } else {
                    // MODO EDICIÓN: Solo lectura (normalmente no se cambia el cliente de un pedido ya hecho)
                    HStack {
                        Text("Cliente")
                        Spacer()
                        Text(viewModel.clienteNombre)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 2: DETALLES
            // -----------------------------------------------------------
            Section("Detalles del Trabajo") {
                TextField("Descripción*", text: $viewModel.descripcion)
                
                Picker("Tipo de Pedido", selection: $viewModel.tipo) {
                    ForEach(TipoPedido.allCases, id: \.self) { tipo in
                        // ANTES: Text(tipo.rawValue.capitalized).tag(tipo)
                        // AHORA: Usamos la nueva propiedad
                        Text(tipo.descripcion).tag(tipo)
                    }
                }
                
                DatePicker("Fecha de Recepción", selection: $viewModel.fecha, displayedComponents: .date)
                
                Toggle("¿Trabajo Entregado?", isOn: $viewModel.estadoEntrega)
                    .tint(.blue)
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 3: PRESUPUESTO
            // -----------------------------------------------------------
            Section("Presupuesto y Pagos") {
                HStack {
                    Text("Presupuesto Total")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    
                    TextField("0", text: $presupuestoInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .onChange(of: presupuestoInput) { _, newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                presupuestoInput = filtered
                            }
                            viewModel.presupuesto = Double(presupuestoInput) ?? 0.0
                        }
                }
                
                // Si estamos editando, mostramos la simulación de la deuda
                if viewModel.isEditing {
                    HStack {
                        Text("Abonado hasta la fecha")
                            .font(.subheadline)
                        Spacer()
                        Text(Formatters.money(viewModel.montoAbonadoOriginal))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    // Cálculo visual (no guarda nada, solo muestra)
                    let deudaProyectada = viewModel.presupuesto - viewModel.montoAbonadoOriginal
                    
                    HStack {
                        Text("Saldo Pendiente (Proyectado)")
                            .font(.subheadline)
                        Spacer()
                        Text(Formatters.money(deudaProyectada))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(deudaProyectada > 0 ? .orange : .green)
                    }
                } else {
                    Text("Al guardar se generará una deuda por el total del presupuesto.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // -----------------------------------------------------------
            // BOTÓN GUARDAR
            // -----------------------------------------------------------
            Section {
                Button(action: viewModel.guardar) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        HStack {
                            Spacer()
                            Text(viewModel.isEditing ? "Actualizar Pedido" : "Crear Pedido")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
        }
        .navigationTitle(viewModel.isEditing ? "Editar Pedido" : "Nuevo Pedido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .errorAlert($viewModel.errorMessage)
        .onChange(of: viewModel.shouldDismiss) {
            if viewModel.shouldDismiss { dismiss() }
        }
        // Carga inicial
        .task {
            // Cargamos contactos solo si es nuevo
            if !viewModel.isEditing && contactos.isEmpty {
                do {
                    contactos = try await TallerRepository().fetchContactos()
                } catch {
                    viewModel.errorMessage = "Error cargando contactos: \(error.localizedDescription)"
                }
            }
        }
        .onAppear {
            // Sincronizar el input de texto con el valor del VM al abrir
            if viewModel.presupuesto > 0 {
                presupuestoInput = String(Int(viewModel.presupuesto))
            }
        }
    }
}
