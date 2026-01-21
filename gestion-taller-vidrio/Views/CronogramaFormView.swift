import SwiftUI

struct CronogramaFormView: View {
    
    // Inyectamos el VM para guardar y para leer el catálogo de cursos
    @ObservedObject var viewModel: CronogramaViewModel
    
    @Environment(\.dismiss) var dismiss
    
    // Campos del formulario
    @State private var selectedCursoID: String = ""
    @State private var fecha: Date = Date()
    
    // Validación
    var isFormValid: Bool {
        !selectedCursoID.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del Evento") {
                    Picker("Curso a Programar*", selection: $selectedCursoID) {
                        Text("Seleccionar un curso...").tag("")
                        // Leemos el catálogo de cursos desde el ViewModel
                        ForEach(viewModel.cursos) { curso in
                            Text(curso.nombre).tag(curso.id ?? "")
                        }
                    }
                    
                    DatePicker("Fecha y Hora*", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Guardar Curso Programado", action: saveCronogramaItem)
                        .disabled(!isFormValid)
                }
            }
            .navigationTitle("Programar Curso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Nos aseguramos de tener el catálogo de cursos cargado
                viewModel.fetchCursos()
            }
        }
    }
    
    /// Prepara el objeto CronogramaItem y lo manda al ViewModel
    private func saveCronogramaItem() {
        // 1. Encontrar el curso seleccionado del catálogo
        guard let selectedCurso = viewModel.cursos.first(where: { $0.id == selectedCursoID }) else {
            print("Error: No se pudo encontrar el curso seleccionado.")
            return
        }
        
        // 2. Crear el nuevo CronogramaItem denormalizando los datos
        let newItem = CronogramaItem(
            cursoId: selectedCurso.id ?? "",
            cursoNombre: selectedCurso.nombre,
            cursoTipo: selectedCurso.tipo,
            precio_curso: selectedCurso.precio,
            fecha: fecha
        )
        
        // 3. Llamar al ViewModel para guardar
        viewModel.saveCronogramaItem(item: newItem)
        
        // 4. Cerrar el formulario
        dismiss()
    }
}

