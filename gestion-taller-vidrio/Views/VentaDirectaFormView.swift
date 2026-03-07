//
//  VentaDirectaFormView.swift
//  gestiontaller
//
//  Created by Victor Krongold on 14/11/2025.
//  Modified by Lead Developer on 04/12/2025 (Integration with SelectorContactoView)
//

import SwiftUI

// Tarea 4.5: Formulario para Venta Directa (Flujo 4)
struct VentaDirectaFormView: View {
    
    @ObservedObject var viewModel: CajaViewModel // ViewModel principal de la caja
    @Environment(\.dismiss) var dismiss
    
    // Instancia dedicada para manejar la creación de contactos en el modal
    @StateObject private var contactosViewModel = ContactosViewModel()
    
    // --- Estado del Formulario ---
    @State private var monto: Double = 0.0
    @State private var medio_de_pago: MedioDePago = .efectivo
    @State private var fecha: Date = Date()
    @State private var notas: String = ""
    @State private var cliente_id: String = ""
    @State private var cliente_nombre: String = "Cliente Ocasional"
    @State private var tipo_venta: TipoVenta = .otros

    // Estado para mostrar el modal
    @State private var showNuevoClienteSheet = false

    // Estados de control
    @State private var isSaving = false
    @State private var errorMessage: String?

    var isFormValid: Bool {
        monto > 0 && !isSaving
    }
    

    
    var body: some View {
        Form {
            // -----------------------------------------------------------
            // SECCIÓN 1: DATOS FINANCIEROS
            // -----------------------------------------------------------
            Section("Datos de la Venta") {
                TextField("Monto*", value: $monto, formatter: Formatters.currencyFormatter)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.blue)
                    .font(.headline)
                
                Picker("Medio de Pago*", selection: $medio_de_pago) {
                    ForEach(MedioDePago.allCases) { medio in
                        Text(medio.rawValue).tag(medio)
                    }
                }
                
                Picker("Tipo de Venta*", selection: $tipo_venta) {
                    ForEach(TipoVenta.allCases) { tipo in
                        Text(tipo.rawValue).tag(tipo)
                    }
                }
                
                DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 2: CLIENTE (SELECTOR MEJORADO)
            // -----------------------------------------------------------
            Section("Cliente (Opcional)") {
                HStack {
                    // 1. Selector con Búsqueda (Reemplaza al Picker)
                    NavigationLink {
                        SelectorContactoView(
                            contactos: viewModel.contactos, // Pasamos la lista del VM
                            selectedID: $cliente_id,
                            selectedNombre: $cliente_nombre
                        )
                    } label: {
                        HStack {
                            Text("Cliente")
                            Spacer()
                            if cliente_id.isEmpty {
                                Text("Cliente Ocasional")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(cliente_nombre)
                                    .foregroundStyle(.primary)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    // 2. Botón (+) para crear nuevo al vuelo (Mantenido)
                    Button(action: {
                        showNuevoClienteSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless) // Importante para que no capture el tap de la celda entera
                    .padding(.leading, 8)
                }
            }
            
            // -----------------------------------------------------------
            // SECCIÓN 3: NOTAS Y GUARDADO
            // -----------------------------------------------------------
            Section("Información Adicional") {
                TextField("Notas (ej: 'Venta de 2 dijes')", text: $notas, axis: .vertical)
                    .lineLimit(4)
            }
            
            Section {
                Button(action: guardarVenta) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Registrar Venta")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid)
            }

        }
        .task { viewModel.fetchContactos() }
        .dismissibleKeyboard()
        .navigationTitle("Nueva Venta Directa")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .errorAlert($errorMessage)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSaving)
            }
        }
        // MODAL DE CREACIÓN DE CLIENTE
        .sheet(isPresented: $showNuevoClienteSheet) {
            NavigationView {
                ContactoFormView(
                    viewModel: contactosViewModel,
                    contactoToEdit: nil,
                    onSaveSuccess: { nuevoContacto in
                        
                        // LÓGICA DE ACTUALIZACIÓN TRAS CREAR:
                        
                        // 1. Inyectamos manualmente en el VM para que aparezca en futuras búsquedas
                        // (Aunque SelectorContactoView se actualizará al reabrirse)
                        viewModel.contactos.append(nuevoContacto)
                        
                        // 2. Asignamos inmediatamente a la Venta Actual
                        if let newId = nuevoContacto.id {
                            self.cliente_id = newId
                            self.cliente_nombre = nuevoContacto.nombreCompleto
                        }
                        
                        // 3. Recarga en background por seguridad
                        Task { viewModel.fetchContactos() }
                    }
                )
            }
        }
    }
    
    private func guardarVenta() {
        let pago = Pago(
            fecha: fecha,
            monto: monto,
            medio_de_pago: medio_de_pago,
            cliente_id: cliente_id.isEmpty ? "default" : cliente_id,
            cliente_nombre: cliente_nombre,
            tipo_venta: tipo_venta,
            notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas,
            origen_tipo: .ventaDirecta,
            descripcion_origen: "Venta Directa: \(tipo_venta.rawValue)",
            origen_id: nil
        )

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.saveVentaDirectaAsync(pago: pago)
                dismiss()
            } catch {
                self.errorMessage = "Error guardando venta: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }
}
