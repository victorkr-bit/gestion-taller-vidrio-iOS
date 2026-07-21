import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("InscripcionesViewModel — listeners, ocupación y acciones")
struct InscripcionesViewModelTests {

    private func makeVM() -> (vm: InscripcionesViewModel, taller: TallerRepositorioFake, finanzas: FinanzasRepositorioFake) {
        let taller = TallerRepositorioFake()
        let finanzas = FinanzasRepositorioFake()
        let vm = InscripcionesViewModel(tallerRepo: taller, finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())
        return (vm, taller, finanzas)
    }

    @Test func emisionPueblaInscripcionesYCalculaOcupacion() {
        let (vm, taller, _) = makeVM()
        vm.fetchInscripciones(cronogramaID: "c1")
        #expect(vm.isLoading)

        // A entra 14:00 (2 turnos), B 13:00 (3 turnos).
        // La ocupación cuenta quiénes están presentes a la hora de ENTRADA de cada uno:
        // cuando A entra (14:00) está B → 2; cuando B entra (13:00) está solo → 1.
        taller.emitirInscripciones(cronogramaID: "c1", [
            TestFactory.inscripcion(id: "i1", horario: "14:00", turnos: 2),
            TestFactory.inscripcion(id: "i2", horario: "13:00", turnos: 3)
        ])

        #expect(vm.inscripciones.count == 2)
        #expect(!vm.isLoading)
        #expect(vm.ocupacionPorInscripcion["i1"] == 2)
        #expect(vm.ocupacionPorInscripcion["i2"] == 1)
    }

    @Test func errorDelListenerSeteaErrorMessage() {
        let (vm, taller, _) = makeVM()
        vm.fetchInscripciones(cronogramaID: "c1")
        taller.emitirErrorInscripciones(cronogramaID: "c1", ErrorDePrueba())
        #expect(vm.errorMessage != nil)
    }

    @Test func inscripcionesOnlineNoCalculanOcupacion() {
        let (vm, taller, _) = makeVM()
        vm.fetchInscripcionesOnline(cursoID: "curso9")

        taller.emitirInscripcionesOnline(cursoID: "curso9", [
            TestFactory.inscripcion(id: "o1", cursoTipo: .online, cronogramaId: nil)
        ])

        #expect(vm.inscripciones.count == 1)
        #expect(vm.ocupacionPorInscripcion.isEmpty)
    }

    @Test func stopListeningInscripcionesCancelaYLimpia() {
        let (vm, taller, _) = makeVM()
        vm.fetchInscripciones(cronogramaID: "c1")
        taller.emitirInscripciones(cronogramaID: "c1", [TestFactory.inscripcion(id: "i1", horario: "14:00", turnos: 1)])

        vm.stopListeningInscripciones()

        #expect(taller.cancelacionesInscripciones["c1"] == 1)
        #expect(vm.inscripciones.isEmpty)
        #expect(vm.ocupacionPorInscripcion.isEmpty)
    }

    @Test func deleteInscripcionConPagosQuedaBloqueada() async {
        let (vm, taller, _) = makeVM()
        let conPagos = TestFactory.inscripcion(id: "i1", montoAbonado: 5_000)

        vm.deleteInscripcion(conPagos)

        #expect(vm.errorMessage != nil)
        let llamado = await esperarCondicion(iteraciones: 50) { !taller.deleteInscripcionLlamadas.isEmpty }
        #expect(!llamado)
    }

    @Test func deleteInscripcionSinPagosLlamaAlRepo() async {
        let (vm, taller, _) = makeVM()
        let sinPagos = TestFactory.inscripcion(id: "i1", montoAbonado: 0)

        vm.deleteInscripcion(sinPagos)

        let llamado = await esperarCondicion { taller.deleteInscripcionLlamadas.count == 1 }
        #expect(llamado)
        #expect(vm.errorMessage == nil)
    }

    @Test func saveInscripcionDelegaAlRepo() async {
        let (vm, taller, _) = makeVM()

        vm.saveInscripcion(inscripcion: TestFactory.inscripcion(nombre: "Carla"))

        let llamado = await esperarCondicion { taller.saveInscripcionLlamadas.count == 1 }
        #expect(llamado)
        #expect(taller.saveInscripcionLlamadas.first?.alumno_nombre == "Carla")
    }

    @Test func guardarConPagoRegistraPagoConOrigenDeLaInscripcionGuardada() async {
        let (vm, taller, finanzas) = makeVM()

        vm.guardarInscripcionConPago(
            inscripcion: TestFactory.inscripcion(nombre: "Carla"),
            montoPago: 4_000,
            medioDePago: .transferencia
        )

        let ok = await esperarCondicion {
            taller.saveInscripcionLlamadas.count == 1 && finanzas.registrarPagoLlamadas.count == 1
        }
        #expect(ok)
        let llamada = finanzas.registrarPagoLlamadas.first
        #expect(llamada?.pago.monto == 4_000)
        #expect(llamada?.pago.medio_de_pago == .transferencia)
        // El origen usa la inscripción con ID poblado por el repo
        #expect(llamada?.origen.id == "inscripcion-creada")
    }

    @Test func guardarConPagoCeroNoRegistraPago() async {
        let (vm, taller, finanzas) = makeVM()

        vm.guardarInscripcionConPago(
            inscripcion: TestFactory.inscripcion(),
            montoPago: 0,
            medioDePago: .efectivo
        )

        let guardado = await esperarCondicion { taller.saveInscripcionLlamadas.count == 1 }
        #expect(guardado)
        #expect(finanzas.registrarPagoLlamadas.isEmpty)
    }

    @Test func acordeonDePagosAbreYCancelaListenerPorInscripcion() {
        let (vm, _, finanzas) = makeVM()
        let inscripcion = TestFactory.inscripcion(id: "i1")

        vm.fetchPagos(para: inscripcion)
        #expect(vm.pagosPorInscripcion["i1"]?.isEmpty == true)

        finanzas.emitirPagos(origenID: "i1", [TestFactory.pago(monto: 900)])
        #expect(vm.pagosPorInscripcion["i1"]?.first?.monto == 900)

        // Reabrir no duplica
        vm.fetchPagos(para: inscripcion)
        #expect(finanzas.pagosPorOrigenCompletions.count == 1)

        vm.stopListeningPagos(para: inscripcion)
        #expect(finanzas.cancelacionesPorOrigen["i1"] == 1)
    }

    @Test func moverInscripcionDelegaConParametros() async throws {
        let (vm, taller, _) = makeVM()

        try await vm.moverInscripcion(inscripcionId: "i1", destinoCronogramaId: "c2", adoptarPrecio: true)

        #expect(taller.moverInscripcionLlamadas.count == 1)
        #expect(taller.moverInscripcionLlamadas.first?.destinoCronogramaId == "c2")
        #expect(taller.moverInscripcionLlamadas.first?.adoptarPrecio == true)
    }

    // MARK: - Preinscripciones

    @Test func preinscripcionesFiltraPendientesYOrdenaPorFechaAscendente() {
        let (vm, taller, _) = makeVM()
        vm.fetchPreinscripciones(cronogramaID: "c1")

        let viejo = Date(timeIntervalSince1970: 1_000)
        let nuevo = Date(timeIntervalSince1970: 2_000)
        taller.emitirPreinscripciones(cronogramaID: "c1", [
            TestFactory.preinscripcion(id: "p2", nombre: "Beto", estado: .pendiente, fechaPreinscripcion: nuevo),
            TestFactory.preinscripcion(id: "p1", nombre: "Ana", estado: .pendiente, fechaPreinscripcion: viejo),
            TestFactory.preinscripcion(id: "p3", nombre: "Cancelada", estado: .cancelada, fechaPreinscripcion: viejo),
            TestFactory.preinscripcion(id: "p4", nombre: "Convertida", estado: .convertida, fechaPreinscripcion: viejo)
        ])

        #expect(vm.preinscripciones.map(\.id) == ["p1", "p2"])
    }

    @Test func preinscripcionSinFechaVaAlFinal() {
        let (vm, taller, _) = makeVM()
        vm.fetchPreinscripciones(cronogramaID: "c1")

        taller.emitirPreinscripciones(cronogramaID: "c1", [
            TestFactory.preinscripcion(id: "pSinFecha", fechaPreinscripcion: nil),
            TestFactory.preinscripcion(id: "pConFecha", fechaPreinscripcion: Date(timeIntervalSince1970: 5_000))
        ])

        #expect(vm.preinscripciones.map(\.id) == ["pConFecha", "pSinFecha"])
    }

    @Test func errorDelListenerDePreinscripcionesSeteaErrorMessage() {
        let (vm, taller, _) = makeVM()
        vm.fetchPreinscripciones(cronogramaID: "c1")
        taller.emitirErrorPreinscripciones(cronogramaID: "c1", ErrorDePrueba())
        #expect(vm.errorMessage != nil)
    }

    @Test func confirmarPreinscripcionDelegaConMontoYMedio() async throws {
        let (vm, taller, _) = makeVM()
        let pre = TestFactory.preinscripcion(id: "p1")

        try await vm.confirmarPreinscripcion(pre, monto: 7_500, medioDePago: .mercadoPago)

        #expect(taller.confirmarPreinscripcionLlamadas.count == 1)
        let llamada = taller.confirmarPreinscripcionLlamadas.first
        #expect(llamada?.id == "p1")
        #expect(llamada?.monto == 7_500)
        #expect(llamada?.medio == .mercadoPago)
    }

    @Test func confirmarPreinscripcionPropagaError() async {
        let (vm, taller, _) = makeVM()
        taller.errorStub = ErrorDePrueba()

        await #expect(throws: Error.self) {
            try await vm.confirmarPreinscripcion(TestFactory.preinscripcion(id: "p1"), monto: 100, medioDePago: .efectivo)
        }
    }

    @Test func descartarPreinscripcionDelegaAlRepo() async {
        let (vm, taller, _) = makeVM()

        vm.descartarPreinscripcion(TestFactory.preinscripcion(id: "p1"))

        let llamado = await esperarCondicion { taller.cancelarPreinscripcionLlamadas.contains("p1") }
        #expect(llamado)
    }

    @Test func stopListeningPreinscripcionesCancelaYLimpia() {
        let (vm, taller, _) = makeVM()
        vm.fetchPreinscripciones(cronogramaID: "c1")
        taller.emitirPreinscripciones(cronogramaID: "c1", [TestFactory.preinscripcion(id: "p1")])

        vm.stopListeningPreinscripciones()

        #expect(taller.cancelacionesPreinscripciones["c1"] == 1)
        #expect(vm.preinscripciones.isEmpty)
    }

    // MARK: - Preinscriptos globales (por card de lista)

    @Test func preinscriptosGlobalAgrupaPorCronogramaSoloPendientes() {
        let (vm, taller, _) = makeVM()
        vm.subscribeToPreinscriptosGlobal()

        taller.emitirPreinscripcionesPendientes([
            TestFactory.preinscripcion(id: "p1", cronogramaId: "c1", estado: .pendiente),
            TestFactory.preinscripcion(id: "p2", cronogramaId: "c1", estado: .pendiente),
            TestFactory.preinscripcion(id: "p3", cronogramaId: "c2", estado: .pendiente),
            TestFactory.preinscripcion(id: "p4", cronogramaId: "c2", estado: .convertida)
        ])

        #expect(vm.preinscriptosPorCronograma["c1"] == 2)
        #expect(vm.preinscriptosPorCronograma["c2"] == 1)
    }

    @Test func preinscriptosGlobalSinDatosParaUnCronogramaQuedaEnCero() {
        let (vm, taller, _) = makeVM()
        vm.subscribeToPreinscriptosGlobal()

        taller.emitirPreinscripcionesPendientes([])

        #expect(vm.preinscriptosPorCronograma["c-inexistente", default: 0] == 0)
    }

    @Test func errorDelListenerGlobalDePreinscriptosSeteaErrorMessage() {
        let (vm, taller, _) = makeVM()
        vm.subscribeToPreinscriptosGlobal()
        taller.emitirErrorPreinscripcionesPendientes(ErrorDePrueba())
        #expect(vm.errorMessage != nil)
    }

    @Test func unsubscribeFromPreinscriptosGlobalCancelaYLimpia() {
        let (vm, taller, _) = makeVM()
        vm.subscribeToPreinscriptosGlobal()
        taller.emitirPreinscripcionesPendientes([TestFactory.preinscripcion(id: "p1", cronogramaId: "c1")])

        vm.unsubscribeFromPreinscriptosGlobal()

        #expect(taller.cancelacionesPreinscripcionesPendientes == 1)
        #expect(vm.preinscriptosPorCronograma.isEmpty)
    }
}
