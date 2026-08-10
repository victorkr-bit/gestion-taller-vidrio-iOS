import SwiftUI

struct PagoRowView: View {
    let pago: Pago

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pago.fecha, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(pago.medio_de_pago.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if pago.categoria_reparto == .adelanto {
                        Text("Adelanto")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                if let notas = pago.notas, !notas.isEmpty {
                    Text(notas)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Formatters.money(pago.monto))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 4)
    }
}
