import SwiftUI

struct MoverCronogramaView: View {

    @ObservedObject var agendaVM: AgendaViewModel
    let item: CronogramaItem
    var onMoved: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss

    @State private var nuevaFecha: Date
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(agendaVM: AgendaViewModel, item: CronogramaItem, onMoved: (() -> Void)? = nil) {
        self.agendaVM = agendaVM
        self.item = item
        self.onMoved = onMoved
        _nuevaFecha = State(initialValue: item.fecha)
    }

    private var mismaFecha: Bool {
        Calendar.current.isDate(nuevaFecha, inSameDayAs: item.fecha)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: DesignSystem.Espaciado.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(DesignSystem.Color.accion)
                    Text(item.cursoNombre)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Fecha actual")
                    Spacer()
                    Text(Formatters.date(item.fecha))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Inscriptos afectados")
                    Spacer()
                    Text("\(item.inscriptosReales)")
                        .foregroundStyle(item.inscriptosReales > 0 ? .orange : .secondary)
                        .fontWeight(item.inscriptosReales > 0 ? .semibold : .regular)
                }
            }

            Section("Nueva fecha") {
                DatePicker(
                    "Seleccionar fecha",
                    selection: $nuevaFecha,
                    displayedComponents: .date
                )
            }

            Section {
                Button(action: confirmarMover) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Label("Confirmar Movimiento", systemImage: "calendar.badge.plus")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(mismaFecha || isSubmitting)
            }
        }
        .navigationTitle("Mover Curso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSubmitting)
            }
        }
        .errorAlert($errorMessage)
    }

    private func confirmarMover() {
        guard let id = item.id else { return }
        isSubmitting = true
        Task {
            do {
                try await agendaVM.actualizarCronograma(
                    id: id,
                    nuevoPrecio: nil,
                    nuevaFecha: ajustarHora(nuevaFecha),
                    nuevasNotas: nil
                )
                dismiss()
                onMoved?()
            } catch {
                errorMessage = "Error al mover curso: \(FirestoreManager.mensajeAmigable(error))"
                isSubmitting = false
            }
        }
    }

    private func ajustarHora(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 13
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}
