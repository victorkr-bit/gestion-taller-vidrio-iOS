import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("MetricasViewModel — KPIs y reacción al filtro")
struct MetricasViewModelTests {

    private func makeVM(filter: FilterCoordinator = FilterCoordinator()) -> (vm: MetricasViewModel, finanzas: FinanzasRepositorioFake, filter: FilterCoordinator) {
        let finanzas = FinanzasRepositorioFake()
        let vm = MetricasViewModel(finanzasRepo: finanzas, filter: filter)
        return (vm, finanzas, filter)
    }

    @Test func metricasEmitidasSumanDeudaTotal() {
        let (vm, finanzas, _) = makeVM()

        var metricas = MetricasFinancieras()
        metricas.total_deuda_pedidos = 1_500
        metricas.total_deuda_inscripciones = 2_500
        finanzas.emitirMetricas(metricas)

        #expect(vm.totalDeuda == 4_000)
    }

    @Test func pagosEmitidosActualizanIngresosDelPeriodo() {
        let (vm, finanzas, _) = makeVM()

        finanzas.emitirPagos([
            TestFactory.pago(id: "a", monto: 1_000),
            TestFactory.pago(id: "b", monto: 250)
        ])

        #expect(vm.totalIngresosMes == 1_250)
        #expect(vm.pagosDelMes.count == 2)
        #expect(!vm.isLoading)
    }

    @Test func datosGraficoAgrupaPorTipoConPorcentajesYOrdenDescendente() {
        let (vm, finanzas, _) = makeVM()

        finanzas.emitirPagos([
            TestFactory.pago(id: "a", monto: 750, tipoVenta: .taller),
            TestFactory.pago(id: "b", monto: 150, tipoVenta: .piezas),
            TestFactory.pago(id: "c", monto: 100, tipoVenta: .piezas)
        ])

        #expect(vm.datosGraficoPorTipo.count == 2)
        // Orden descendente por monto
        #expect(vm.datosGraficoPorTipo[0].tipo == TipoVenta.taller.descripcion)
        #expect(vm.datosGraficoPorTipo[0].monto == 750)
        #expect(vm.datosGraficoPorTipo[0].porcentaje == 75)
        #expect(vm.datosGraficoPorTipo[1].monto == 250)
        #expect(vm.datosGraficoPorTipo[1].porcentaje == 25)
    }

    @Test func resumenDeudaSeparaRealDeFuturo() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.resumenDeudaStub = (real: 3_000, futuro: 7_000)
        let vm = MetricasViewModel(finanzasRepo: finanzas, filter: FilterCoordinator())

        let ok = await esperarCondicion { vm.totalDeudaReal == 3_000 && vm.totalMontoCobrar == 7_000 }
        #expect(ok)
    }

    @Test func tendenciaComparaContraVentanaAnteriorDeIgualDuracion() {
        let (vm, finanzas, filter) = makeVM()

        // Período = mes actual (duración 1). Ingresos del período: 1.200.
        finanzas.emitirPagos([TestFactory.pago(monto: 1_200)])

        // Mes inmediatamente anterior facturó 1.000.
        let cal = Calendar.current
        let mesAnterior = cal.date(byAdding: .month, value: -1, to: filter.mesInicio.fechaInicio)!
        let dato = DatoMensual(
            mes: cal.component(.month, from: mesAnterior),
            año: cal.component(.year, from: mesAnterior),
            total: 1_000
        )

        let tendencia = vm.tendenciaPorcentaje(facturacionAnual: [dato])
        #expect(abs(tendencia - 20.0) < 0.001) // (1200-1000)/1000
    }

    @Test func tendenciaSinHistorialDevuelveCero() {
        let (vm, finanzas, _) = makeVM()
        finanzas.emitirPagos([TestFactory.pago(monto: 1_200)])

        #expect(vm.tendenciaPorcentaje(facturacionAnual: []) == 0)
    }

    @Test func cambioDeFiltroReiniciaListenerConNuevoRango() {
        let (_, finanzas, filter) = makeVM()
        let rangosIniciales = finanzas.rangosRecibidos.count

        let nuevoPeriodo = MesAño(mes: 1, año: 2025)
        filter.mesInicio = nuevoPeriodo

        #expect(finanzas.rangosRecibidos.count == rangosIniciales + 1)
        #expect(finanzas.ultimoRango?.from == nuevoPeriodo.fechaInicio)
    }

    @Test func errorEnMetricasSeteaErrorMessage() {
        let (vm, finanzas, _) = makeVM()
        finanzas.metricasCompletion?(.failure(ErrorDePrueba()))
        #expect(vm.errorMessage != nil)
    }
}
