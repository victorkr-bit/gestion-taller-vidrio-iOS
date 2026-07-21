import SwiftUI
import FirebaseFirestore

/// Fila de una preinscripción pendiente de pago (cursos presenciales).
/// Sin acordeón de pagos: la preinscripción aún no es una inscripción firme.
struct PreinscripcionRowView: View {
    let preinscripcion: Preinscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    /// Set para abrir el sheet de confirmación de pago en la vista padre.
    @Binding var preinscripcionParaConfirmar: Preinscripcion?

    @State private var showDescartarAlert = false

    private var fechaTexto: String? {
        preinscripcion.fecha_preinscripcion.map { Formatters.date($0.dateValue()) }
    }

    var body: some View {
        CardView(tint: DesignSystem.Color.alerta) {
            GenericRowView(
                titulo: preinscripcion.nombreCompleto,
                subtitulo: preinscripcion.notas.flatMap { $0.isEmpty ? nil : $0 }
                    ?? preinscripcion.contactoResumen,
                infoSuperior: fechaTexto,
                iconoSuperior: nil,
                monto: nil,
                tags: [TagConfig(text: "Pendiente", color: DesignSystem.Color.alerta)]
            )
        }
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                self.preinscripcionParaConfirmar = preinscripcion
            } label: {
                Label("Confirmar pago", systemImage: "dollarsign.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDescartarAlert = true
            } label: {
                Label("Descartar", systemImage: "trash.fill")
            }
            .tint(.red)
        }
        .contextMenu {
            Button {
                self.preinscripcionParaConfirmar = preinscripcion
            } label: {
                Label("Confirmar pago", systemImage: "dollarsign.circle")
            }
            Button(role: .destructive) {
                showDescartarAlert = true
            } label: {
                Label("Descartar", systemImage: "trash")
            }
        }
        .alert("Descartar preinscripción", isPresented: $showDescartarAlert) {
            Button("Descartar", role: .destructive) {
                inscripcionesVM.descartarPreinscripcion(preinscripcion)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Descartar la preinscripción de \(preinscripcion.nombreCompleto)?")
        }
    }
}
