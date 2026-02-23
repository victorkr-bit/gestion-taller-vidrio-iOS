import SwiftUI

struct CursoFormView: View {
    
    @ObservedObject var viewModel: CursosViewModel
    var cursoToEdit: Curso?
    
    @Environment(\.dismiss) var dismiss
    
    // Campos del formulario
    @State private var nombre: String = ""
    @State private var tipo: TipoCurso = .presencial // Valor default
    @State private var precio: Double = 0.0
    
    /// Formateador de moneda para el TextField de Precio.
    /// Respeta la configuración regional de Argentina [user_memory].
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        // Usamos es_AR para formato de Argentina (ej: $ 1.234,50)
        formatter.locale = Locale(identifier: "es_AR")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }
    
    // Validación
    var isFormValid: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        Form {
            Section("Detalles del Curso") {
                TextField("Nombre del Curso*", text: $nombre)
                
                // Tarea 2.2: Picker usando TipoCurso.allCases
                Picker("Tipo de Curso", selection: $tipo) {
                    ForEach(TipoCurso.allCases) { tipoCurso in
                        Text(tipoCurso.descripcion).tag(tipoCurso)
                    }
                }
                
                // Tarea 2.2: TextField para Double (precio)
                TextField("Precio", value: $precio, formatter: currencyFormatter)
                    .keyboardType(.decimalPad)
            }
            
            Section {
                Button(action: guardarCurso) {
                    Text("Guardar Curso")
                }
                .disabled(!isFormValid)
            }
        }
        .dismissibleKeyboard()
        .navigationTitle(cursoToEdit == nil ? "Nuevo Curso" : "Editar Curso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Si editamos, cargamos los datos
            if let curso = cursoToEdit {
                nombre = curso.nombre
                tipo = curso.tipo
                precio = curso.precio
            }
        }
    }
    
    private func guardarCurso() {
        var curso = cursoToEdit ?? Curso(
            nombre: "", // Se sobreescribe abajo
            tipo: .presencial,
            precio: 0.0
        )
        
        curso.nombre = nombre.trimmingCharacters(in: .whitespaces)
        curso.tipo = tipo
        curso.precio = precio
        
        viewModel.saveCurso(curso: curso)
        
        dismiss()
    }
}
