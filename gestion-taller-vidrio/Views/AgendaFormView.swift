import SwiftUI

struct AgendaFormView: View {

    // Inyectamos el VM para guardar y para leer el catálogo de cursos
    @ObservedObject var agendaVM: AgendaViewModel

    @Environment(\.dismiss) var dismiss

    // Campos del formulario
    @State private var selectedCursoID: String = ""
    @State private var fecha: Date = .now
    @State private var cupoInput: String = ""

    // Validación
    var isFormValid: Bool {
        !selectedCursoID.isEmpty
    }

    private var cursoSeleccionado: Curso? {
        agendaVM.cursos.first { $0.id == selectedCursoID }
    }

    private var esPresencial: Bool {
        cursoSeleccionado?.tipo == .presencial
    }

    private var hoy: Date {
        Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Form {
            Section("Datos del Evento") {
                Picker("Curso a Programar*", selection: $selectedCursoID) {
                    Text("Seleccionar un curso...").tag("")
                    // Leemos el catálogo de cursos desde el ViewModel
                    ForEach(agendaVM.cursos) { curso in
                        Text(curso.nombre).tag(curso.id ?? "")
                    }
                }

                DatePicker(
                    "Fecha de Inicio*",
                    selection: $fecha,
                    in: hoy...,
                    displayedComponents: .date
                )
            }

            if esPresencial {
                Section("Cupo") {
                    HStack {
                        Text("Cupo máximo")
                        Spacer()
                        Text("N°").foregroundStyle(.secondary)
                        TextField("Sin límite", text: $cupoInput.numericOnly())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Text("Opcional. Vacío = sin límite.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .task {
            agendaVM.fetchCursos()
        }
    }

    /// Prepara el objeto CronogramaItem y lo manda al ViewModel
    private func saveCronogramaItem() {
        // 1. Encontrar el curso seleccionado del catálogo
        guard let selectedCurso = agendaVM.cursos.first(where: { $0.id == selectedCursoID }) else {
            agendaVM.errorMessage = "No se pudo encontrar el curso seleccionado."
            return
        }

        // Lógica para fijar la hora a las 13:00
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fecha)
        components.hour = 13
        components.minute = 0
        components.second = 0

        // Si la construcción falla por algún motivo, usamos la fecha original
        let fechaFinal = calendar.date(from: components) ?? fecha

        // 2. Crear el nuevo CronogramaItem con la fecha ajustada
        let cupo: Int? = (selectedCurso.tipo == .presencial) ? Int(cupoInput).flatMap { $0 > 0 ? $0 : nil } : nil
        let newItem = CronogramaItem(
            cursoId: selectedCurso.id ?? "",
            cursoNombre: selectedCurso.nombre,
            cursoTipo: selectedCurso.tipo,
            precio_curso: selectedCurso.precio,
            fecha: fechaFinal,
            cupo_maximo: cupo
        )

        // 3. Llamar al ViewModel para guardar
        agendaVM.saveCronogramaItem(item: newItem)

        // 4. Cerrar el formulario
        dismiss()
    }
}
