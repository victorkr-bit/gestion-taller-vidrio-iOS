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

@Suite("TallerCalculator — ocupación por hora leída de slot_ocupacion")
struct OcupacionPorHoraTests {

    @Test func sinSlotOcupacionDevuelveElHorarioDelTallerEnCero() {
        let item = TestFactory.cronogramaItem(horaInicio: "13:00", horaFin: "21:00")
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        #expect(resultado.map(\.hora) == Array(13...21))
        #expect(resultado.allSatisfy { $0.cantidad == 0 })
    }

    @Test func sinHorarioUsaElRangoPorDefecto() {
        let item = TestFactory.cronogramaItem(slotOcupacion: ["14": 2])
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        #expect(resultado.map(\.hora) == Array(13...21))
        #expect(resultado.first { $0.hora == 14 }?.cantidad == 2)
    }

    @Test func leeLasClavesConCeroAdelante() {
        // El backend escribe las horas padeadas a dos dígitos: "09", no "9".
        let item = TestFactory.cronogramaItem(
            horaInicio: "09:00",
            horaFin: "12:00",
            slotOcupacion: ["09": 3, "10": 1]
        )
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        let porHora = Dictionary(uniqueKeysWithValues: resultado.map { ($0.hora, $0.cantidad) })
        #expect(porHora[9] == 3)
        #expect(porHora[10] == 1)
        #expect(porHora[11] == 0)
    }

    @Test func elRangoSeEnsanchaSiHaySlotsFueraDelHorario() {
        // Alguien quedó agendado a las 22 en un taller que cierra a las 21.
        let item = TestFactory.cronogramaItem(
            horaInicio: "13:00",
            horaFin: "21:00",
            slotOcupacion: ["22": 1]
        )
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        #expect(resultado.map(\.hora) == Array(13...22))
        #expect(resultado.last?.cantidad == 1)
    }

    @Test func elRangoSeEnsanchaHaciaAtras() {
        let item = TestFactory.cronogramaItem(
            horaInicio: "13:00",
            horaFin: "21:00",
            slotOcupacion: ["11": 2]
        )
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        #expect(resultado.map(\.hora) == Array(11...21))
        #expect(resultado.first?.cantidad == 2)
    }

    @Test func clavesInvalidasNoRompenElRango() {
        let item = TestFactory.cronogramaItem(
            horaInicio: "13:00",
            horaFin: "21:00",
            slotOcupacion: ["basura": 5, "15": 1]
        )
        let resultado = TallerCalculator.ocupacionPorHora(de: item)
        #expect(resultado.map(\.hora) == Array(13...21))
        #expect(resultado.first { $0.hora == 15 }?.cantidad == 1)
    }

    @Test func horarioInvertidoDevuelveVacioEnVezDeRomper() {
        let item = TestFactory.cronogramaItem(horaInicio: "21:00", horaFin: "13:00")
        #expect(TallerCalculator.ocupacionPorHora(de: item).isEmpty)
    }
}
