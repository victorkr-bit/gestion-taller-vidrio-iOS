import SwiftUI

struct CursoFormView: View {
    
    @ObservedObject var viewModel: CursosViewModel
    var cursoToEdit: Curso?
    
    @Environment(\.dismiss) var dismiss
    
    // Campos del formulario
    @State private var nombre: String = ""
    @State private var tipo: TipoCurso = .presencial // Valor default
    @State private var precio: Double = 0.0

    @State private var actualizacionInfo: (cronogramas: Int, inscripciones: Int)?
    @State private var mostrarAlertaActualizacion = false
    
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
                
                if cursoToEdit == nil {
                    Picker("Tipo de Curso", selection: $tipo) {
                        ForEach(TipoCurso.allCases) { tipoCurso in
                            Text(tipoCurso.descripcion).tag(tipoCurso)
                        }
                    }
                } else {
                    LabeledContent("Tipo de Curso", value: tipo.descripcion)
                }
                
                // Tarea 2.2: TextField para Double (precio)
                TextField("Precio", value: $precio, formatter: currencyFormatter)
                    .keyboardType(.decimalPad)
            }
            
            Section {
                Button {
                    Task { await guardarCurso() }
                } label: {
                    Text("Guardar Curso")
                }
                .disabled(!isFormValid || viewModel.isLoading)
            }
        }
        .dismissibleKeyboard()
        .alert("Curso actualizado", isPresented: $mostrarAlertaActualizacion) {
            Button("Entendido") { dismiss() }
        } message: {
            if let info = actualizacionInfo {
                let cronText = info.cronogramas == 1 ? "1 cronograma" : "\(info.cronogramas) cronogramas"
                let inscText = info.inscripciones == 1 ? "1 inscripción" : "\(info.inscripciones) inscripciones"
                Text("Nombre propagado a \(cronText) y \(inscText).")
            }
        }
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
    
    private func guardarCurso() async {
        var curso = cursoToEdit ?? Curso(
            nombre: "", // Se sobreescribe abajo
            tipo: .presencial,
            precio: 0.0
        )

        curso.nombre = nombre.trimmingCharacters(in: .whitespaces)
        curso.tipo = tipo
        curso.precio = precio

        let resultado = await viewModel.saveCurso(curso: curso)

        if viewModel.errorMessage != nil {
            return // El error queda visible en el formulario
        }

        if let info = resultado {
            // Actualización: mostrar alerta con conteo antes de cerrar
            actualizacionInfo = info
            mostrarAlertaActualizacion = true
        } else {
            dismiss()
        }
    }
}
