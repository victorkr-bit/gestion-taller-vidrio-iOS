import SwiftUI

struct PagosListView: View {
    let inscripcion: Inscripcion
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    var body: some View {
        if let id = inscripcion.id, let pagos = inscripcionesVM.pagosPorInscripcion[id] {
            if pagos.isEmpty {
                Text("No hay pagos registrados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(pagos) { pago in
                    PagosListRow(pago: pago, inscripcionesVM: inscripcionesVM)
                        .padding(.leading, 20)
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                }
            }
        } else {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Subvista de Fila

/// El alert vive en el `@State` de esta subvista (no del `ForEach`/lista padre):
/// colgarlo a nivel de lista hace que el diffing del List anidado en el acordeón
/// cierre la presentación casi al instante. Mismo patrón que `PagosRow` en PagosView.swift.
///
/// El botón del swipeAction NO usa `role: .destructive` — ese role dispara el
/// comportamiento de borrado automático de fila de SwiftUI, que corre en paralelo
/// al cambio de `@State` y cierra el `.alert` de confirmación casi al instante.
/// `PagosView.swift` (patrón que sí funciona) usa un botón plano + `.tint(.red)`.
private struct PagosListRow: View {
    let pago: Pago
    @ObservedObject var inscripcionesVM: InscripcionesViewModel

    @State private var showDeleteAlert = false

    var body: some View {
        PagoRowView(pago: pago)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Label("Borrar", systemImage: "trash.fill")
                }
                .tint(.red)
            }
            .alert("Eliminar Pago", isPresented: $showDeleteAlert) {
                Button("Eliminar", role: .destructive) {
                    inscripcionesVM.deletePago(pago)
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("¿Eliminar el pago de \(Formatters.money(pago.monto))? Esta acción no se puede deshacer.")
            }
    }
}
