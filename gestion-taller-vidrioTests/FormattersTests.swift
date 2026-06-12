import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("Formatters — moneda")
struct MoneyFormatterTests {

    @Test func monedaArgentinaSinDecimales() {
        let resultado = Formatters.money(1_234_567)
        #expect(resultado.contains("1.234.567"))
        #expect(resultado.contains("$"))
        // 0 decimales: no aparece el separador decimal argentino
        #expect(!resultado.contains(","))
    }

    @Test func montoConDecimalesSeRedondea() {
        let resultado = Formatters.money(1500.75)
        #expect(resultado.contains("1.501"))
    }

    @Test func cero() {
        #expect(Formatters.money(0).contains("0"))
    }

    @Test func compactoMillones() {
        #expect(Formatters.compactMoney(4_150_000) == "$4,15M")
        #expect(Formatters.compactMoney(1_000_000) == "$1M")
        #expect(Formatters.compactMoney(2_500_000) == "$2,5M")
    }

    @Test func compactoMiles() {
        #expect(Formatters.compactMoney(45_000) == "$45K")
        #expect(Formatters.compactMoney(45_500) == "$45,5K")
    }

    @Test func compactoMenorAMilUsaMoneyNormal() {
        #expect(Formatters.compactMoney(800) == Formatters.money(800))
    }
}

@Suite("Formatters — fechas")
struct DateFormatterTests {

    /// Construye una fecha desde componentes en una timezone dada.
    private func fecha(_ año: Int, _ mes: Int, _ día: Int, _ hora: Int = 12, _ minuto: Int = 0,
                       tz: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: año, month: mes, day: día, hour: hora, minute: minuto))!
    }

    @Test func fechaCortaEnEspañolCapitalizada() {
        let d = fecha(2025, 12, 9)
        let resultado = Formatters.date(d)
        #expect(resultado.contains("9"))
        #expect(resultado.contains("Dic"))
        #expect(resultado.contains("2025"))
    }

    @Test func horaFormatoVeinticuatro() {
        let d = fecha(2026, 6, 12, 18, 30)
        #expect(Formatters.time(d) == "18:30")
    }

    @Test func diaMes() {
        let d = fecha(2026, 10, 12)
        #expect(Formatters.dateDayMonth(d) == "12/10")
    }

    @Test func dateOnlyUsaTimezoneArgentina() {
        let tzAR = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let d = fecha(2026, 6, 12, 15, 0, tz: tzAR)
        #expect(Formatters.dateOnly(d) == "2026-06-12")
    }

    @Test func dateOnlyCruceDeAñoEnUTCsigueSiendoDiaAnteriorEnArgentina() {
        // 2026-01-01 01:00 UTC == 2025-12-31 22:00 en Argentina (UTC-3)
        let tzUTC = TimeZone(identifier: "UTC")!
        let d = fecha(2026, 1, 1, 1, 0, tz: tzUTC)
        #expect(Formatters.dateOnly(d) == "2025-12-31")
    }
}

@Suite("Formatters — ISO8601")
struct ISO8601Tests {

    @Test func parseaFraccionesDeSegundo() {
        let date = Formatters.iso8601.date(from: "2026-06-12T15:30:00.000Z")
        #expect(date != nil)
    }

    @Test func idaYVueltaPreservaElInstante() {
        let original = "2026-06-12T15:30:45.500Z"
        let date = Formatters.iso8601.date(from: original)!
        #expect(Formatters.iso8601.string(from: date) == original)
    }

    @Test func sinFraccionesNoParsea() {
        // El formatter exige fracciones (.withFractionalSeconds): contrato con Cloud Functions.
        #expect(Formatters.iso8601.date(from: "2026-06-12T15:30:00Z") == nil)
    }
}
