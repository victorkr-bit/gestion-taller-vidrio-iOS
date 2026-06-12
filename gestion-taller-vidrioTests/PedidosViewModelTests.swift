import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("PedidosViewModel — listener y filtros")
struct PedidosViewModelFiltrosTests {

    private func makeVM() -> (vm: PedidosViewModel, ventas: VentasRepositorioFake, finanzas: FinanzasRepositorioFake) {
        let ventas = VentasRepositorioFake()
        let finanzas = FinanzasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: ventas, finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())
        return (vm, ventas, finanzas)
    }

    @Test func emisionDelListenerPueblaPedidos() {
        let (vm, ventas, _) = makeVM()
        #expect(vm.isLoading)

        ventas.emitirPedidos([TestFactory.pedido(id: "p1"), TestFactory.pedido(id: "p2")])

        #expect(vm.pedidos.count == 2)
        #expect(!vm.isLoading)
    }

    @Test func errorDelListenerSeteaErrorMessage() {
        let (vm, ventas, _) = makeVM()
        ventas.emitirErrorPedidos(ErrorDePrueba())
        #expect(vm.errorMessage != nil)
    }

    @Test func filtroTextoBuscaEnClienteDescripcionYNumero() {
        let (vm, ventas, _) = makeVM()
        vm.filtroEntregaSeleccionado = .todos
        ventas.emitirPedidos([
            TestFactory.pedido(id: "p1", numero: "P-0100", cliente: "Ana García", descripcion: "Vitral redondo"),
            TestFactory.pedido(id: "p2", numero: "P-0200", cliente: "Beto Pérez", descripcion: "Espejo biselado")
        ])

        vm.searchText = "ana gar" // case-insensitive en cliente
        #expect(vm.pedidosVisibles.map(\.id) == ["p1"])

        vm.searchText = "BISELADO" // descripción
        #expect(vm.pedidosVisibles.map(\.id) == ["p2"])

        vm.searchText = "p-0100" // número de pedido
        #expect(vm.pedidosVisibles.map(\.id) == ["p1"])

        vm.searchText = "inexistente"
        #expect(vm.pedidosVisibles.isEmpty)
    }

    @Test func filtroPagadosExigeEstadoPagoYPresupuestoPositivo() {
        let (vm, ventas, _) = makeVM()
        vm.filtroEntregaSeleccionado = .todos
        ventas.emitirPedidos([
            TestFactory.pedido(id: "pagado", presupuesto: 1_000, estadoPago: true),
            TestFactory.pedido(id: "sinPresupuesto", presupuesto: 0, estadoPago: true),
            TestFactory.pedido(id: "pendiente", presupuesto: 1_000, estadoPago: false)
        ])

        vm.filtroPagoSeleccionado = .pagados
        #expect(vm.pedidosVisibles.map(\.id) == ["pagado"])

        // Regla espejo: presupuesto 0 cuenta como pendiente aunque estado_pago sea true
        vm.filtroPagoSeleccionado = .pendientes
        #expect(Set(vm.pedidosVisibles.compactMap(\.id)) == ["sinPresupuesto", "pendiente"])
    }

    @Test func filtroEntregaArrancaEnPendientesPorDefecto() {
        let (vm, ventas, _) = makeVM()
        ventas.emitirPedidos([
            TestFactory.pedido(id: "entregado", estadoEntrega: true),
            TestFactory.pedido(id: "pendiente", estadoEntrega: false)
        ])

        #expect(vm.filtroEntregaSeleccionado == .pendientes)
        #expect(vm.pedidosVisibles.map(\.id) == ["pendiente"])

        vm.filtroEntregaSeleccionado = .entregados
        #expect(vm.pedidosVisibles.map(\.id) == ["entregado"])

        vm.filtroEntregaSeleccionado = .todos
        #expect(vm.pedidosVisibles.count == 2)
    }

    @Test func filtrosCombinadosSeAplicanEnCadena() {
        let (vm, ventas, _) = makeVM()
        ventas.emitirPedidos([
            TestFactory.pedido(id: "objetivo", presupuesto: 500, cliente: "Carla", estadoPago: true, estadoEntrega: true),
            TestFactory.pedido(id: "otroCliente", presupuesto: 500, cliente: "Diego", estadoPago: true, estadoEntrega: true),
            TestFactory.pedido(id: "noPagado", presupuesto: 500, cliente: "Carla", estadoPago: false, estadoEntrega: true),
            TestFactory.pedido(id: "noEntregado", presupuesto: 500, cliente: "Carla", estadoPago: true, estadoEntrega: false)
        ])

        vm.searchText = "carla"
        vm.filtroPagoSeleccionado = .pagados
        vm.filtroEntregaSeleccionado = .entregados

        #expect(vm.pedidosVisibles.map(\.id) == ["objetivo"])
    }
}

@Suite("PedidosViewModel — borrado y acordeón de pagos")
struct PedidosViewModelAccionesTests {

    @Test func deletePedidoConPagosQuedaBloqueado() async {
        let ventas = VentasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: ventas, finanzasRepo: FinanzasRepositorioFake(), contactosRepo: ContactosRepositorioFake())
        let conPagos = TestFactory.pedido(id: "p1", presupuesto: 1_000, montoAbonado: 300)
        ventas.emitirPedidos([conPagos])

        vm.deletePedido(conPagos)

        #expect(vm.errorMessage != nil)
        #expect(vm.pedidos.count == 1) // no se quitó de la lista
        let llamado = await esperarCondicion(iteraciones: 50) { !ventas.deletePedidoLlamadas.isEmpty }
        #expect(!llamado) // nunca llegó al repo
    }

    @Test func deletePedidoSinPagosQuitaLocalYLlamaAlRepo() async {
        let ventas = VentasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: ventas, finanzasRepo: FinanzasRepositorioFake(), contactosRepo: ContactosRepositorioFake())
        let sinPagos = TestFactory.pedido(id: "p1", montoAbonado: 0)
        ventas.emitirPedidos([sinPagos])

        vm.deletePedido(sinPagos)

        #expect(vm.pedidos.isEmpty) // borrado optimista inmediato
        let llamado = await esperarCondicion { ventas.deletePedidoLlamadas.count == 1 }
        #expect(llamado)
        #expect(vm.errorMessage == nil)
    }

    @Test func acordeonAbreListenerPorPedidoYColapsoLoCancela() {
        let finanzas = FinanzasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: VentasRepositorioFake(), finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())
        let pedido = TestFactory.pedido(id: "p1")

        vm.fetchPagos(para: pedido)
        #expect(vm.pagosPorPedido["p1"]?.isEmpty == true) // placeholder inmediato

        finanzas.emitirPagos(origenID: "p1", [TestFactory.pago(monto: 700)])
        #expect(vm.pagosPorPedido["p1"]?.first?.monto == 700)

        // Reabrir no duplica listener
        vm.fetchPagos(para: pedido)
        #expect(finanzas.pagosPorOrigenCompletions.count == 1)

        vm.stopListeningPagos(para: pedido)
        #expect(finanzas.cancelacionesPorOrigen["p1"] == 1)
    }

    @Test func cleanupCancelaTodosLosListenersDePagos() {
        let finanzas = FinanzasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: VentasRepositorioFake(), finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())

        vm.fetchPagos(para: TestFactory.pedido(id: "p1"))
        vm.fetchPagos(para: TestFactory.pedido(id: "p2"))
        vm.cleanupPaymentListeners()

        #expect(finanzas.cancelacionesPorOrigen["p1"] == 1)
        #expect(finanzas.cancelacionesPorOrigen["p2"] == 1)
        #expect(vm.pagosPorPedido.isEmpty)
    }

    @Test func registrarPagoDelegaAlRepo() async throws {
        let finanzas = FinanzasRepositorioFake()
        let vm = PedidosViewModel(ventasRepo: VentasRepositorioFake(), finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())
        let pedido = TestFactory.pedido(id: "p1")

        try await vm.registrarPago(pago: TestFactory.pago(monto: 500), origen: .pedido(pedido))

        #expect(finanzas.registrarPagoLlamadas.count == 1)
        #expect(finanzas.registrarPagoLlamadas.first?.pago.monto == 500)
    }
}
