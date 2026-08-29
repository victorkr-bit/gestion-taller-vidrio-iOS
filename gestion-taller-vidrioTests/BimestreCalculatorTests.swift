import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("BimestreCalculator — agrupación por bimestre calendario")
struct BimestreCalculatorTests {

    private func dato(mes: Int, año: Int, nuevos: Int = 1, repiten: Int = 0) -> DatoMensualRetencion {
        DatoMensualRetencion(mes: mes, año: año, nuevos: nuevos, repiten: repiten)
    }

    /// Ventana "actual" (hoy = agosto '26): sep '25 ... ago '26. Calza justo con bimestre
    /// calendario (sep-oct empieza la ventana, jul-ago la termina) → 6 bimestres completos.
    @Test func ventanaQueEmpiezaYTerminaEnBordeDeBimestreDaSeisCompletos() {
        let meses = [
            dato(mes: 9, año: 2025), dato(mes: 10, año: 2025),
            dato(mes: 11, año: 2025), dato(mes: 12, año: 2025),
            dato(mes: 1, año: 2026), dato(mes: 2, año: 2026),
            dato(mes: 3, año: 2026), dato(mes: 4, año: 2026),
            dato(mes: 5, año: 2026), dato(mes: 6, año: 2026),
            dato(mes: 7, año: 2026), dato(mes: 8, año: 2026)
        ]
        let resultado = BimestreCalculator.agrupar(meses)

        #expect(resultado.count == 6)
        // "sept" (no "sep") es lo que devuelve el locale es_AR de iOS para septiembre.
        #expect(resultado.map(\.labelEje) == ["sept-oct", "nov-dic", "ene-feb", "mar-abr", "may-jun", "jul-ago"])
        // Cada bimestre suma sus dos meses (1+1 nuevos cada uno en el fixture).
        #expect(resultado.allSatisfy { $0.nuevos == 2 })
    }

    /// Ventana cuando arranca septiembre '26 (hoy = 15-sep-2026): oct '25 ... sep '26.
    /// Ahora la ventana arranca y termina A MITAD de un bimestre real → quedan 7 baldes,
    /// dos de ellos con un solo mes (los bordes).
    @Test func ventanaQueEmpiezaAMitadDeBimestreDejaBordesParciales() {
        let meses = [
            dato(mes: 10, año: 2025), dato(mes: 11, año: 2025),
            dato(mes: 12, año: 2025), dato(mes: 1, año: 2026),
            dato(mes: 2, año: 2026), dato(mes: 3, año: 2026),
            dato(mes: 4, año: 2026), dato(mes: 5, año: 2026),
            dato(mes: 6, año: 2026), dato(mes: 7, año: 2026),
            dato(mes: 8, año: 2026), dato(mes: 9, año: 2026)
        ]
        let resultado = BimestreCalculator.agrupar(meses)

        #expect(resultado.count == 7)
        #expect(resultado.map(\.labelEje) == [
            "oct", "nov-dic", "ene-feb", "mar-abr", "may-jun", "jul-ago", "sept"
        ])
        // Los bordes son un solo mes → suman 1, no 2.
        #expect(resultado.first?.nuevos == 1)
        #expect(resultado.last?.nuevos == 1)
        // Los del medio (bimestre completo) suman 2.
        #expect(resultado.dropFirst().dropLast().allSatisfy { $0.nuevos == 2 })
    }

    @Test func sumaNuevosYRepitenDeAmbosMesesDelBimestre() {
        let meses = [
            dato(mes: 7, año: 2026, nuevos: 3, repiten: 1),
            dato(mes: 8, año: 2026, nuevos: 2, repiten: 4)
        ]
        let resultado = BimestreCalculator.agrupar(meses)

        #expect(resultado.count == 1)
        #expect(resultado.first?.labelEje == "jul-ago")
        #expect(resultado.first?.nuevos == 5)
        #expect(resultado.first?.repiten == 5)
    }

    @Test func ordenaCronologicamenteAunqueElInputEsteDesordenado() {
        let meses = [
            dato(mes: 3, año: 2026), dato(mes: 4, año: 2026),
            dato(mes: 1, año: 2026), dato(mes: 2, año: 2026)
        ]
        let resultado = BimestreCalculator.agrupar(meses)

        #expect(resultado.map(\.labelEje) == ["ene-feb", "mar-abr"])
    }

    @Test func vacioDevuelveVacio() {
        #expect(BimestreCalculator.agrupar([]).isEmpty)
    }
}
