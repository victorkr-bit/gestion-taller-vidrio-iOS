import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("MesAño — rangos de período")
struct MesAñoTests {

    private let tzAR = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    private func componentes(de fecha: Date) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tzAR
        return cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fecha)
    }

    @Test func fechaInicioEsPrimerDiaDelMesEnArgentina() {
        let c = componentes(de: MesAño(mes: 6, año: 2026).fechaInicio)
        #expect(c.year == 2026)
        #expect(c.month == 6)
        #expect(c.day == 1)
        #expect(c.hour == 0)
        #expect(c.minute == 0)
    }

    @Test func fechaFinEsUltimoInstanteDelMes() {
        let c = componentes(de: MesAño(mes: 6, año: 2026).fechaFin)
        #expect(c.year == 2026)
        #expect(c.month == 6)
        #expect(c.day == 30)
        #expect(c.hour == 23)
        #expect(c.minute == 59)
    }

    @Test func fechaFinDeDiciembreNoSeDesbordaAlAñoSiguiente() {
        let c = componentes(de: MesAño(mes: 12, año: 2025).fechaFin)
        #expect(c.year == 2025)
        #expect(c.month == 12)
        #expect(c.day == 31)
    }

    @Test func febreroBisiesto() {
        let c = componentes(de: MesAño(mes: 2, año: 2024).fechaFin)
        #expect(c.day == 29)
    }

    @Test func inicioEsAnteriorAlFin() {
        let m = MesAño(mes: 6, año: 2026)
        #expect(m.fechaInicio < m.fechaFin)
    }

    @Test func currentReflejaElMesActual() {
        let actual = MesAño.current()
        let cal = Calendar.current
        #expect(actual.mes == cal.component(.month, from: Date()))
        #expect(actual.año == cal.component(.year, from: Date()))
    }

    @Test func shortLabelContieneMesYAño() {
        let label = MesAño(mes: 6, año: 2026).shortLabel
        #expect(label.contains("2026"))
        #expect(label.lowercased().contains("jun"))
    }
}

@Suite("FilterCoordinator — período compartido")
@MainActor
struct FilterCoordinatorTests {

    @Test func periodoLabelMesUnico() {
        let coordinator = FilterCoordinator()
        coordinator.mesInicio = MesAño(mes: 6, año: 2026)
        coordinator.mesFin = MesAño(mes: 6, año: 2026)
        #expect(coordinator.periodoLabel == MesAño(mes: 6, año: 2026).shortLabel)
    }

    @Test func periodoLabelMismoAñoOmiteAñoInicial() {
        let coordinator = FilterCoordinator()
        coordinator.mesInicio = MesAño(mes: 3, año: 2026)
        coordinator.mesFin = MesAño(mes: 6, año: 2026)
        let label = coordinator.periodoLabel
        #expect(label.contains("–"))
        // El año aparece una sola vez (solo en el extremo final)
        #expect(label.components(separatedBy: "2026").count == 2)
    }

    @Test func periodoLabelAñosDistintosMuestraAmbos() {
        let coordinator = FilterCoordinator()
        coordinator.mesInicio = MesAño(mes: 11, año: 2025)
        coordinator.mesFin = MesAño(mes: 2, año: 2026)
        let label = coordinator.periodoLabel
        #expect(label.contains("2025"))
        #expect(label.contains("2026"))
    }

    @Test func sincronizarVuelveAlMesActual() {
        let coordinator = FilterCoordinator()
        coordinator.mesInicio = MesAño(mes: 1, año: 2024)
        coordinator.mesFin = MesAño(mes: 2, año: 2024)
        coordinator.sincronizarMesActualSiCambio()
        #expect(coordinator.mesInicio == MesAño.current())
        #expect(coordinator.mesFin == MesAño.current())
    }

    @Test func sincronizarNoTocaNadaSiYaEstaEnElMesActual() {
        let coordinator = FilterCoordinator()
        coordinator.sincronizarMesActualSiCambio()
        #expect(coordinator.mesInicio == MesAño.current())
        #expect(coordinator.mesFin == MesAño.current())
    }
}
