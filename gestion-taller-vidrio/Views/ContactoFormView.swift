//
//  ContactoFormView.swift
//  gestiontaller
//
//  Created by Victor Krongold on 13/11/2025.
//

import SwiftUI

struct ContactoFormView: View {
    
    @ObservedObject var viewModel: ContactosViewModel
    var contactoToEdit: Contacto?
    @Environment(\.dismiss) var dismiss
    
    // NUEVO: Closure para avisar al padre que se guardó exitosamente y pasarle el contacto
    var onSaveSuccess: ((Contacto) -> Void)?
    
    // Campos del formulario
    @State private var nombre: String = ""
    @State private var apellido: String = ""
    @State private var email: String = ""
    @State private var telefono: String = ""
    @State private var direccion: String = ""
    @State private var redes_sociales: String = ""
    @State private var cuit: String = ""
    @State private var notas: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    var isFormValid: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apellido.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }
    
    var body: some View {
        Form {
            Section("Datos Requeridos") {
                TextField("Nombre*", text: $nombre)
                TextField("Apellido*", text: $apellido)
            }
            
            Section("Datos de Contacto (Opcional)") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Teléfono", text: $telefono)
                    .keyboardType(.phonePad)
                TextField("Dirección", text: $direccion)
            }
            
            Section("Datos Adicionales (Opcional)") {
                TextField("Redes Sociales", text: $redes_sociales)
                TextField("CUIT/CUIL", text: $cuit)
                    .keyboardType(.numberPad)
                
                VStack(alignment: .leading) {
                    Text("Notas").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $notas).frame(minHeight: 100)
                }
            }
            
            Section {
                Button(action: guardarContacto) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Guardar Contacto")
                    }
                }
                .disabled(!isFormValid)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(contactoToEdit == nil ? "Nuevo Contacto" : "Editar Contacto")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSaving)
            }
        }
        .onAppear {
            if let contacto = contactoToEdit {
                nombre = contacto.nombre
                apellido = contacto.apellido
                email = contacto.email ?? ""
                telefono = contacto.telefono ?? ""
                direccion = contacto.direccion ?? ""
                redes_sociales = contacto.redes_sociales ?? ""
                cuit = contacto.cuit ?? ""
                notas = contacto.notas ?? ""
            }
        }
    }
   
    private func guardarContacto() {
        let targetID = contactoToEdit?.id ?? UUID().uuidString

        var contactoData = Contacto(id: nil, nombre: "", apellido: "")
        contactoData.nombre = nombre.trimmingCharacters(in: .whitespaces)
        contactoData.apellido = apellido.trimmingCharacters(in: .whitespaces)
        contactoData.email = email.isEmpty ? nil : email
        contactoData.telefono = telefono.isEmpty ? nil : telefono
        contactoData.direccion = direccion.isEmpty ? nil : direccion
        contactoData.redes_sociales = redes_sociales.isEmpty ? nil : redes_sociales
        contactoData.cuit = cuit.isEmpty ? nil : cuit
        contactoData.notas = notas.isEmpty ? nil : notas

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.saveContactoAsync(datos: contactoData, id: targetID)

                var contactoParaUI = contactoData
                contactoParaUI.id = targetID
                onSaveSuccess?(contactoParaUI)
                dismiss()
            } catch {
                self.errorMessage = "Error al guardar: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }
   
}
