import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("RetencionCalculator — nuevos vs. repiten por mes")
struct RetencionCalculatorTests {

    private func fecha(_ yyyyMMdd: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        return df.date(from: yyyyMMdd)!
    }

    @Test func primeraInscripcionEsNueva() {
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial, fechaCurso: fecha("2026-01-10"))
        ]
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado["2026-01"]?.nuevos == 1)
        #expect(resultado["2026-01"]?.repiten == 0)
    }

    @Test func segundaInscripcionMismoAlumnoEsRepite() {
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial, fechaCurso: fecha("2026-01-10")),
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .taller, fechaCurso: fecha("2026-02-05"))
        ]
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado["2026-01"]?.nuevos == 1)
        #expect(resultado["2026-02"]?.repiten == 1)
        #expect(resultado["2026-02"]?.nuevos == nil || resultado["2026-02"]?.nuevos == 0)
    }

    @Test func historicoOnlineCuentaComoPrimeraActividadPeroNoSeGrafica() {
        // Primer contacto del alumno fue un curso online (no debe aparecer como barra),
        // pero su siguiente presencial ya es "repite", no "nuevo".
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .online, fechaCurso: fecha("2025-12-01")),
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial, fechaCurso: fecha("2026-01-10"))
        ]
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado["2025-12"] == nil) // online no grafica
        #expect(resultado["2026-01"]?.nuevos == 0)
        #expect(resultado["2026-01"]?.repiten == 1)
    }

    @Test func canceladasNoCuentanNiParaElSetNiParaElConteo() {
        // Las canceladas nunca llegan acá (fallan a decodificar en el repo), pero si llegaran
        // una inscripcion con estado != .inscripto/.pagado no puede construirse — el enum
        // solo admite esos dos casos. Este test documenta esa garantía indirectamente:
        // pasar solo activas produce el conteo correcto, sin necesidad de filtrar canceladas acá.
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial, fechaCurso: fecha("2026-01-10"))
        ]
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado.count == 1)
    }

    @Test func ordenaPorFechaInscripcionConFallbackAFechaCurso() {
        // Mismo alumno, dos inscripciones. La que tiene fecha_curso posterior (feb) en realidad
        // se anotó antes (fecha_inscripcion enero) → debe procesarse primero y quedar "nueva".
        // La otra (fecha_curso enero, sin fecha_inscripcion → fallback a fecha_curso enero) se
        // procesa después → "repite", aunque su fecha_curso sea anterior en el calendario.
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial,
                                     fechaCurso: fecha("2026-02-01"), fechaInscripcion: fecha("2026-01-01")),
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .taller,
                                     fechaCurso: fecha("2026-01-15"), fechaInscripcion: nil)
        ]
        // Ambas caen en el mismo balde (2026-01, la fecha de orden de la primera): 1 nuevo, 1 repite.
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado["2026-01"]?.nuevos == 1)
        #expect(resultado["2026-01"]?.repiten == 1)
    }

    @Test func agrupaVariasInscripcionesDelMismoMes() {
        let ins = [
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .presencial, fechaCurso: fecha("2026-03-01")),
            TestFactory.inscripcion(alumnoId: "a2", cursoTipo: .taller, fechaCurso: fecha("2026-03-15")),
            TestFactory.inscripcion(alumnoId: "a1", cursoTipo: .taller, fechaCurso: fecha("2026-03-20"))
        ]
        let resultado = RetencionCalculator.porMes(inscripciones: ins)
        #expect(resultado["2026-03"]?.nuevos == 2) // a1 y a2 primera vez
        #expect(resultado["2026-03"]?.repiten == 1) // a1 de nuevo, mismo mes
    }

    @Test func inscripcionVaciaDevuelveDiccionarioVacio() {
        #expect(RetencionCalculator.porMes(inscripciones: []).isEmpty)
    }
}
