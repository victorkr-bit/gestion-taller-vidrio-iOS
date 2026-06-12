import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("ChartsViewModel — facturación anual y detalle de clases")
struct ChartsViewModelTests {

    @Test func facturacionAnualAgrupaPagosPorMes() {
        let finanzas = FinanzasRepositorioFake()
        let vm = ChartsViewModel(finanzasRepo: finanzas, tallerRepo: TallerRepositorioFake(), filter: FilterCoordinator())

        let cal = Calendar.current
        let hoy = Date()
        let mesPasado = cal.date(byAdding: .month, value: -1, to: hoy)!

        finanzas.emitirPagos([
            TestFactory.pago(id: "a", monto: 500, fecha: hoy),
            TestFactory.pago(id: "b", monto: 300, fecha: hoy),
            TestFactory.pago(id: "c", monto: 200, fecha: mesPasado)
        ])

        // Ventana fija: 13 cubetas, índice 0 = mes actual
        #expect(vm.facturacionAnual.count == 13)
        #expect(vm.facturacionAnual[0].total == 800)
        #expect(vm.facturacionAnual[1].total == 200)
        #expect(vm.facturacionAnual[2].total == 0)
        #expect(vm.facturacionAnual[0].mes == cal.component(.month, from: hoy))
        #expect(vm.facturacionAnual[0].año == cal.component(.year, from: hoy))
    }

    @Test func detalleClasesSeparaPorTipoYAgrupaPorCurso() async {
        let taller = TallerRepositorioFake()
        // 2 alumnos en el mismo taller (1 clase), 1 presencial, 2 online del mismo curso
        taller.inscripcionesStub = [
            TestFactory.inscripcion(id: "t1", cursoNombre: "Taller", cursoTipo: .taller, cronogramaId: "cronoA"),
            TestFactory.inscripcion(id: "t2", cursoNombre: "Taller", cursoTipo: .taller, cronogramaId: "cronoA"),
            TestFactory.inscripcion(id: "p1", cursoNombre: "Vitrofusión", cursoTipo: .presencial, cronogramaId: "cronoB"),
            TestFactory.inscripcion(id: "o1", cursoNombre: "Curso Online", cursoTipo: .online, cronogramaId: nil),
            TestFactory.inscripcion(id: "o2", cursoNombre: "Curso Online", cursoTipo: .online, cronogramaId: nil)
        ]
        let vm = ChartsViewModel(finanzasRepo: FinanzasRepositorioFake(), tallerRepo: taller, filter: FilterCoordinator())

        let cargado = await esperarCondicion { vm.detalleClases.taller != nil }
        #expect(cargado)

        #expect(vm.detalleClases.taller?.clases == 1)   // cronograma único
        #expect(vm.detalleClases.taller?.alumnos == 2)

        #expect(vm.detalleClases.presencial.count == 1)
        #expect(vm.detalleClases.presencial.first?.nombre == "Vitrofusión")
        #expect(vm.detalleClases.presencial.first?.alumnos == 1)

        #expect(vm.detalleClases.online.count == 1)
        #expect(vm.detalleClases.online.first?.alumnos == 2)
        #expect(vm.detalleClases.online.first?.clases == nil) // online no tiene clases
    }

    @Test func detalleClasesVacioSinInscripciones() async {
        let taller = TallerRepositorioFake()
        taller.inscripcionesStub = []
        let vm = ChartsViewModel(finanzasRepo: FinanzasRepositorioFake(), tallerRepo: taller, filter: FilterCoordinator())

        // Esperamos a que el fetch del init haya corrido
        _ = await esperarCondicion { !taller.rangosFechaPedidos.isEmpty }
        await Task.yield()

        #expect(vm.detalleClases.taller == nil)
        #expect(vm.detalleClases.presencial.isEmpty)
        #expect(vm.detalleClases.online.isEmpty)
    }

    @Test func clasesAnualesCuentaCronogramasUnicosPorMes() async {
        let taller = TallerRepositorioFake()
        let cal = Calendar.current
        let esteMes = Date()
        taller.inscripcionesStub = [
            TestFactory.inscripcion(id: "i1", cronogramaId: "cronoA", fechaCurso: esteMes),
            TestFactory.inscripcion(id: "i2", cronogramaId: "cronoA", fechaCurso: esteMes),
            TestFactory.inscripcion(id: "i3", cronogramaId: "cronoB", fechaCurso: esteMes)
        ]
        let vm = ChartsViewModel(finanzasRepo: FinanzasRepositorioFake(), tallerRepo: taller, filter: FilterCoordinator())

        let cargado = await esperarCondicion { !vm.clasesAnuales.isEmpty }
        #expect(cargado)
        #expect(vm.clasesAnuales.count == 12)

        // El último elemento es el mes actual (ventana ordenada hacia el presente)
        let actual = vm.clasesAnuales.last
        #expect(actual?.mes == cal.component(.month, from: esteMes))
        #expect(actual?.clases == 2)  // cronoA + cronoB
        #expect(actual?.alumnos == 3)
    }

    @Test func cambioDeFiltroRecargaDetalleDelPeriodo() async {
        let taller = TallerRepositorioFake()
        let filter = FilterCoordinator()
        let vm = ChartsViewModel(finanzasRepo: FinanzasRepositorioFake(), tallerRepo: taller, filter: filter)

        _ = await esperarCondicion { taller.rangosFechaPedidos.count >= 2 } // init: clases anuales + detalle
        let llamadasIniciales = taller.rangosFechaPedidos.count

        filter.mesInicio = MesAño(mes: 1, año: 2025)

        let recargado = await esperarCondicion { taller.rangosFechaPedidos.count > llamadasIniciales }
        #expect(recargado)
        // El nuevo fetch arranca en el inicio del período elegido
        #expect(taller.rangosFechaPedidos.last?.from == MesAño(mes: 1, año: 2025).fechaInicio)
        _ = vm // mantener vivo el VM: si se libera, muere la suscripción al filtro
    }
}
