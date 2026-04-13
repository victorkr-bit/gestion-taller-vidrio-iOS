import SwiftUI

struct EditarAgendaView: View {

    @ObservedObject var agendaVM: AgendaViewModel
    let cronogramaItem: CronogramaItem

    @Environment(\.dismiss) var dismiss

    @State private var precioInput: String = ""
    @State private var fecha: Date = Date()
    @State private var notas: String = ""
    @State private var isSaving = false

    private var precioValido: Double? {
        let valor = Double(precioInput)
        return (valor != nil && valor! >= 0) ? valor : nil
    }

    private var hayCambios: Bool {
        let precioCambio = precioValido != nil && precioValido != cronogramaItem.precio_curso
        let fechaCambio = !Calendar.current.isDate(fecha, inSameDayAs: cronogramaItem.fecha)
        let notasCambio = notas != (cronogramaItem.notas ?? "")
        return precioCambio || fechaCambio || notasCambio
    }

    var body: some View {
        Form {
            // Sección 1: Info del curso (solo lectura)
            Section("Curso") {
                HStack {
                    Text("Nombre")
                    Spacer()
                    Text(cronogramaItem.cursoNombre)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Inscriptos")
                    Spacer()
                    Text("\(cronogramaItem.inscriptosReales)")
                        .foregroundStyle(.secondary)
                }
            }

            // Sección 2: Precio
            Section("Precio") {
                HStack {
                    Text("Precio actual")
                    Spacer()
                    Text(Formatters.money(cronogramaItem.precio_curso))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Nuevo precio")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", text: $precioInput.numericOnly())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                if cronogramaItem.inscriptosReales > 0 {
                    Text("Se actualizará la deuda de \(cronogramaItem.inscriptosReales) inscripto(s).")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Sección 3: Notas
            Section("Notas") {
                TextField("Observaciones sobre la clase", text: $notas, axis: .vertical)
                    .lineLimit(3...6)
            }

            // Sección 4: Fecha
            Section("Fecha") {
                DatePicker(
                    "Nueva fecha",
                    selection: $fecha,
                    displayedComponents: .date
                )
            }

            // Guardar
            Section {
                Button(action: guardar) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar Cambios")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(!hayCambios || isSaving)
            }
        }
        .dismissibleKeyboard()
        .navigationTitle("Editar Curso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .onAppear {
            precioInput = String(Int(cronogramaItem.precio_curso))
            fecha = cronogramaItem.fecha
            notas = cronogramaItem.notas ?? ""
        }
    }

    private func guardar() {
        guard let id = cronogramaItem.id else { return }

        let nuevoPrecio: Double? = (precioValido != nil && precioValido != cronogramaItem.precio_curso)
            ? precioValido : nil
        let nuevaFecha: Date? = Calendar.current.isDate(fecha, inSameDayAs: cronogramaItem.fecha)
            ? nil : ajustarHora(fecha)
        let nuevasNotas: String? = notas != (cronogramaItem.notas ?? "") ? notas : nil

        isSaving = true

        Task {
            do {
                try await agendaVM.actualizarCronograma(id: id, nuevoPrecio: nuevoPrecio, nuevaFecha: nuevaFecha, nuevasNotas: nuevasNotas)
                dismiss()
            } catch is CancellationError {
                isSaving = false
            } catch {
                agendaVM.errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    /// Fija la hora a las 13:00 para mantener consistencia con AgendaFormView.
    private func ajustarHora(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 13
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}
