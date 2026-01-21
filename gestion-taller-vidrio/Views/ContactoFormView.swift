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
    
    var isFormValid: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apellido.trimmingCharacters(in: .whitespaces).isEmpty
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
                    Text("Guardar Contacto")
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle(contactoToEdit == nil ? "Nuevo Contacto" : "Editar Contacto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
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
        // 1. DETERMINAR EL ID (ESTRATEGIA UI OPTIMISTA)
        // Si editamos, usamos el existente. Si es nuevo, generamos uno ahora mismo.
        let targetID = contactoToEdit?.id ?? UUID().uuidString
        
        // 2. CREAR EL OBJETO DE DATOS (PARA FIRESTORE)
        // IMPORTANTE: Pasamos 'id: nil' aquí. Esto ELIMINA el warning de Firestore.
        var contactoData = Contacto(
            id: nil, // <--- La clave del éxito. Firestore no verá un ID forzado dentro del objeto.
            nombre: "",
            apellido: ""
        )
        
        // Llenamos los datos
        contactoData.nombre = nombre.trimmingCharacters(in: .whitespaces)
        contactoData.apellido = apellido.trimmingCharacters(in: .whitespaces)
        contactoData.email = email.isEmpty ? nil : email
        contactoData.telefono = telefono.isEmpty ? nil : telefono
        contactoData.direccion = direccion.isEmpty ? nil : direccion
        contactoData.redes_sociales = redes_sociales.isEmpty ? nil : redes_sociales
        contactoData.cuit = cuit.isEmpty ? nil : cuit
        contactoData.notas = notas.isEmpty ? nil : notas
        
        // 3. GUARDAR EN FIRESTORE
        // Pasamos el objeto limpio y el ID por separado
        viewModel.saveContacto(datos: contactoData, id: targetID)
        
        // 4. PREPARAR OBJETO PARA LA UI (CALLBACK)
        // Como contactoData tiene id: nil, creamos una copia o lo asignamos manualmente
        // solo para devolverlo a la vista padre (VentaDirecta o Inscripcion).
        var contactoParaUI = contactoData
        contactoParaUI.id = targetID // Aquí sí asignamos el ID para que la lista lo reconozca
        
        // Avisamos al padre con el objeto completo
        onSaveSuccess?(contactoParaUI)
        
        dismiss()
    }
   
}
