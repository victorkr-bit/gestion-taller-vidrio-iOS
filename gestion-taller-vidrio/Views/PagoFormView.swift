//
//  PagoFormView.swift
//  gestiontaller
//
//  Created by Victor Krongold on 14/11/2025.
//


import SwiftUI

// Tarea 4.5: Formulario para Editar un Pago (Flujo 3)
struct PagoFormView: View {
    
    @ObservedObject var viewModel: CajaViewModel
    var pagoToEdit: Pago
    @Environment(\.dismiss) var dismiss
    
    // --- Estado del Formulario ---
    @State private var monto: Double
    @State private var medio_de_pago: MedioDePago
    @State private var fecha: Date
    @State private var notas: String
    
    // Guardamos el monto original para el Flujo 3 (Delta)
    private let montoAntiguo: Double
    
    var isFormValid: Bool {
        monto > 0
    }
    
    // Inicializador para cargar el estado desde el pago a editar
    init(viewModel: CajaViewModel, pagoToEdit: Pago) {
        self.viewModel = viewModel
        self.pagoToEdit = pagoToEdit
        
        // Inicializamos el @State
        _monto = State(initialValue: pagoToEdit.monto)
        _medio_de_pago = State(initialValue: pagoToEdit.medio_de_pago)
        _fecha = State(initialValue: pagoToEdit.fecha)
        _notas = State(initialValue: pagoToEdit.notas ?? "")
        
        // Guardamos el monto original
        self.montoAntiguo = pagoToEdit.monto
    }

    var body: some View {
        Form {
            Section("Datos del Pago") {
                TextField("Monto*", value: $monto, formatter: Formatters.currencyFormatter)
                    .keyboardType(.decimalPad)
                
                Picker("Medio de Pago*", selection: $medio_de_pago) {
                    ForEach(MedioDePago.allCases) { medio in
                        Text(medio.rawValue).tag(medio)
                    }
                }
                
                DatePicker("Fecha", selection: $fecha)
            }
            
            Section("Información Adicional") {
                TextField("Notas", text: $notas, axis: .vertical)
                    .lineLimit(4)
                
                // Campos informativos (no editables)
                Text("Cliente: \(pagoToEdit.cliente_nombre)")
                    .foregroundStyle(.secondary)
                Text("Origen: \(pagoToEdit.descripcion_origen)")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button(action: guardarCambios) {
                    Text("Guardar Cambios")
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle("Editar Pago")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }
    
    private func guardarCambios() {
        // Creamos una copia actualizada del pago
        var pagoActualizado = pagoToEdit
        
        pagoActualizado.monto = monto
        pagoActualizado.medio_de_pago = medio_de_pago
        pagoActualizado.fecha = fecha
        pagoActualizado.notas = notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas
        
        // Llamamos al Flujo 3 (Delta)
        viewModel.savePagoEditado(pago: pagoActualizado, montoAntiguo: self.montoAntiguo)
        dismiss()
    }
}
