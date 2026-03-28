//
//  MoverInscripcionView.swift
//  gestiontaller
//

import SwiftUI

struct MoverInscripcionView: View {

    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    let inscripcion: Inscripcion
    let cronogramasDisponibles: [CronogramaItem]

    @Environment(\.dismiss) var dismiss

    /// Callback invocado tras un traslado exitoso (útil cuando la vista se presenta como destino de NavigationLink).
    var onMoved: (() -> Void)? = nil

    @State private var destinoSeleccionado: CronogramaItem? = nil
    @State private var adoptarPrecio = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var nuevoPrecio: Double? {
        guard let destino = destinoSeleccionado else { return nil }
        let esTaller = inscripcion.cursoTipo == .taller
        return destino.precio_curso * Double(esTaller ? (inscripcion.turnos ?? 1) : 1)
    }

    var nuevaDeuda: Double? {
        guard let precio = nuevoPrecio else { return nil }
        return max(0, precio - inscripcion.monto_abonado)
    }

    var body: some View {
        Form {
            Section("Alumno") {
                Text(inscripcion.alumno_nombre)
                    .fontWeight(.semibold)
                Text("Precio actual: \(Formatters.money(inscripcion.precio_curso))")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Section("Cronograma destino") {
                if cronogramasDisponibles.isEmpty {
                    Text("No hay otros cronogramas futuros disponibles.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(cronogramasDisponibles) { item in
                        Button {
                            withAnimation { destinoSeleccionado = item }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.cursoNombre)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(item.fecha, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Formatters.money(item.precio_curso))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if destinoSeleccionado?.id == item.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Precio") {
                Toggle("Adoptar precio del destino", isOn: $adoptarPrecio)

                if adoptarPrecio, let precio = nuevoPrecio, let deuda = nuevaDeuda {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Nuevo precio:")
                            Spacer()
                            Text(Formatters.money(precio))
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Ya abonado:")
                            Spacer()
                            Text(Formatters.money(inscripcion.monto_abonado))
                                .foregroundStyle(.green)
                        }
                        Divider()
                        HStack {
                            Text("Nueva deuda:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(Formatters.money(deuda))
                                .fontWeight(.bold)
                                .foregroundStyle(deuda <= 0 ? .green : .orange)
                        }
                    }
                    .font(.subheadline)
                }
            }

            Section {
                Button(action: confirmarMover) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Label("Confirmar Traslado", systemImage: "arrow.right.circle.fill")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(destinoSeleccionado == nil || isSubmitting)
            }
        }
        .navigationTitle("Mover Inscripto")
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
        guard let destino = destinoSeleccionado,
              let inscripcionId = inscripcion.id,
              let destinoId = destino.id else { return }

        isSubmitting = true
        Task {
            do {
                try await inscripcionesVM.moverInscripcion(
                    inscripcionId: inscripcionId,
                    destinoCronogramaId: destinoId,
                    adoptarPrecio: adoptarPrecio
                )
                dismiss()
                onMoved?()
            } catch {
                errorMessage = "Error al mover inscripción: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}
