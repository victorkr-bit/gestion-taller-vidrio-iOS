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
                    PagoRowView(pago: pago)
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
