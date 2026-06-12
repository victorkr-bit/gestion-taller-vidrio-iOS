import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("TallerCalculator — conversión de horarios")
struct MinutosDesdeMedianocheTests {

    @Test func horarioValido() {
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "14:30") == 870)
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "00:00") == 0)
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "9:00") == 540)
    }

    @Test func horarioNilDevuelveNil() {
        #expect(TallerCalculator.minutosDesdeMedianoche(from: nil) == nil)
    }

    @Test func horarioMalformadoDevuelveNil() {
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "abc") == nil)
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "14") == nil)
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "14:30:00") == nil)
        #expect(TallerCalculator.minutosDesdeMedianoche(from: "aa:bb") == nil)
    }
}

@Suite("TallerCalculator — ocupación por alumno")
struct OcupacionPorAlumnoTests {

    @Test func superposicionNormal() {
        // A entra 14:00. B está 13:00–16:00 (3 turnos). A (2 turnos) se cuenta a sí mismo.
        let a = TestFactory.inscripcion(horario: "14:00", turnos: 2)
        let b = TestFactory.inscripcion(horario: "13:00", turnos: 3)
        #expect(TallerCalculator.calcularOcupacion(para: a, enLista: [a, b]) == 2)
    }

    @Test func rangoSemiabiertoNoIncluyeFinExacto() {
        // B 13:00 con 1 turno → rango [13:00, 14:00). A entra justo a las 14:00 → no superpone.
        let a = TestFactory.inscripcion(horario: "14:00", turnos: 1)
        let b = TestFactory.inscripcion(horario: "13:00", turnos: 1)
        #expect(TallerCalculator.calcularOcupacion(para: a, enLista: [a, b]) == 1)
    }

    @Test func otroSinTurnosSeIgnora() {
        let a = TestFactory.inscripcion(horario: "14:00", turnos: 1)
        let sinTurnos = TestFactory.inscripcion(horario: "13:00", turnos: nil)
        #expect(TallerCalculator.calcularOcupacion(para: a, enLista: [a, sinTurnos]) == 1)
    }

    @Test func alumnoSinHorarioDevuelveCero() {
        let a = TestFactory.inscripcion(horario: nil, turnos: 2)
        let b = TestFactory.inscripcion(horario: "13:00", turnos: 3)
        #expect(TallerCalculator.calcularOcupacion(para: a, enLista: [a, b]) == 0)
    }

    @Test func listaVaciaDevuelveCero() {
        let a = TestFactory.inscripcion(horario: "14:00", turnos: 1)
        #expect(TallerCalculator.calcularOcupacion(para: a, enLista: []) == 0)
    }
}

@Suite("TallerCalculator — ocupación por hora")
struct OcupacionPorHoraTests {

    @Test func sinInscripcionesDevuelveRangoFijoEnCero() {
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [])
        #expect(resultado.count == 9)
        #expect(resultado.map(\.hora) == Array(13...21))
        #expect(resultado.allSatisfy { $0.cantidad == 0 })
    }

    @Test func inscripcionDeDosTurnosOcupaDosHoras() {
        let i = TestFactory.inscripcion(horario: "14:00", turnos: 2)
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [i])
        let porHora = Dictionary(uniqueKeysWithValues: resultado.map { ($0.hora, $0.cantidad) })
        #expect(porHora[14] == 1)
        #expect(porHora[15] == 1)
        #expect(porHora[13] == 0)
        #expect(porHora[16] == 0)
    }

    @Test func inicioConMinutosExtraOcupaHoraAdicional() {
        // 14:30 con 1 turno → llega hasta 15:30 → afecta las horas 14 y 15.
        let i = TestFactory.inscripcion(horario: "14:30", turnos: 1)
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [i])
        let porHora = Dictionary(uniqueKeysWithValues: resultado.map { ($0.hora, $0.cantidad) })
        #expect(porHora[14] == 1)
        #expect(porHora[15] == 1)
        #expect(porHora[16] == 0)
    }

    @Test func turnosNilCuentaComoUnTurno() {
        let i = TestFactory.inscripcion(horario: "14:00", turnos: nil)
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [i])
        let porHora = Dictionary(uniqueKeysWithValues: resultado.map { ($0.hora, $0.cantidad) })
        #expect(porHora[14] == 1)
        #expect(porHora[15] == 0)
    }

    @Test func horarioFueraDelRangoFijoNoApareceEnResultado() {
        let i = TestFactory.inscripcion(horario: "10:00", turnos: 1)
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [i])
        #expect(resultado.map(\.hora) == Array(13...21))
        #expect(resultado.allSatisfy { $0.cantidad == 0 })
    }

    @Test func variasInscripcionesSeAcumulan() {
        let i1 = TestFactory.inscripcion(horario: "14:00", turnos: 2)
        let i2 = TestFactory.inscripcion(horario: "15:00", turnos: 1)
        let resultado = TallerCalculator.calcularOcupacionPorHora(para: [i1, i2])
        let porHora = Dictionary(uniqueKeysWithValues: resultado.map { ($0.hora, $0.cantidad) })
        #expect(porHora[14] == 1)
        #expect(porHora[15] == 2)
    }
}
