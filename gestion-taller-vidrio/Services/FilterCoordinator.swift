import Foundation
import Combine

@MainActor
final class FilterCoordinator: ObservableObject {

    @Published var mesInicio: MesAño = .current()
    @Published var mesFin: MesAño = .current()

    /// Si la app estuvo en background y ahora estamos en un mes nuevo,
    /// resincroniza el filtro al mes actual.
    func sincronizarMesActualSiCambio() {
        let actual = MesAño.current()
        if mesInicio != actual || mesFin != actual {
            mesInicio = actual
            mesFin = actual
        }
    }

    var periodoLabel: String {
        if mesInicio == mesFin {
            return mesInicio.shortLabel
        } else if mesInicio.año == mesFin.año {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "es_AR")
            let inicioStr = cal.shortMonthSymbols[mesInicio.mes - 1].capitalized
            return "\(inicioStr) – \(mesFin.shortLabel)"
        } else {
            return "\(mesInicio.shortLabel) – \(mesFin.shortLabel)"
        }
    }
}
