import SwiftUI

struct PagoRowView: View {
    let pago: Pago

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pago.fecha, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pago.medio_de_pago.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
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
