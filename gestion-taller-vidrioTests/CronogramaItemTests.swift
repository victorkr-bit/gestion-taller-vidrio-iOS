import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("CronogramaItem — formato x/y/z de inscriptos")
struct CronogramaItemTests {

    @Test func cupoDefinidoFormateaLosTresValores() {
        let item = TestFactory.cronogramaItem(cursoTipo: .presencial, inscriptos: 3, cupo: 10)
        #expect(item.textoInscriptos(preinscriptos: 2) == "2/3/10")
    }

    @Test func cupoIndefinidoUsaGuion() {
        let item = TestFactory.cronogramaItem(cursoTipo: .presencial, inscriptos: 5, cupo: nil)
        #expect(item.textoInscriptos(preinscriptos: 0) == "0/5/-")
    }

    @Test func sinInscriptosNiPreinscriptosMuestraCeros() {
        let item = TestFactory.cronogramaItem(cursoTipo: .presencial, inscriptos: nil, cupo: 8)
        #expect(item.textoInscriptos(preinscriptos: 0) == "0/0/8")
    }
}
