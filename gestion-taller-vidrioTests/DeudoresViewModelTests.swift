import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("DeudoresViewModel — totales, búsqueda y orden")
struct DeudoresViewModelTests {

    private func deudorPedido(id: String, nombre: String, monto: Double, fecha: Date = Date(timeIntervalSince1970: 1_750_000_000)) -> DeudorItem {
        DeudorItem(pedido: TestFactory.pedido(id: id, presupuesto: monto, fecha: fecha, numero: "N-\(id)", cliente: nombre))
    }

    private func deudorInscripcion(id: String, nombre: String, monto: Double) -> DeudorItem {
        DeudorItem(inscripcion: TestFactory.inscripcion(id: id, nombre: nombre, montoAdeudado: monto))
    }

    @Test func fetchDeudoresPueblaListaDesdeElRepo() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.deudoresStub = [deudorPedido(id: "d1", nombre: "Ana", monto: 100)]
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())

        let cargado = await esperarCondicion { vm.deudores.count == 1 }
        #expect(cargado)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
    }

    @Test func errorDelRepoSeteaErrorMessage() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.errorStub = ErrorDePrueba()
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())

        let fallo = await esperarCondicion { vm.errorMessage != nil }
        #expect(fallo)
        #expect(vm.deudores.isEmpty)
    }

    @Test func totalesSeparanPedidosDeInscripciones() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.deudoresStub = [
            deudorPedido(id: "p1", nombre: "Ana", monto: 100),
            deudorPedido(id: "p2", nombre: "Beto", monto: 250),
            deudorInscripcion(id: "i1", nombre: "Carla", monto: 1_000)
        ]
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { vm.deudores.count == 3 }

        #expect(vm.totalDeudaPedidos == 350)
        #expect(vm.totalDeudaInscripciones == 1_000)
    }

    @Test func ordenamientoPorMontoYFecha() async {
        let finanzas = FinanzasRepositorioFake()
        let vieja = Date(timeIntervalSince1970: 1_700_000_000)
        let nueva = Date(timeIntervalSince1970: 1_760_000_000)
        finanzas.deudoresStub = [
            deudorPedido(id: "chico", nombre: "Ana", monto: 100, fecha: nueva),
            deudorPedido(id: "grande", nombre: "Beto", monto: 900, fecha: vieja)
        ]
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { vm.deudores.count == 2 }

        vm.orden = .montoDescendente
        #expect(vm.deudoresFiltrados.map(\.id) == ["grande", "chico"])

        vm.orden = .fechaDescendente
        #expect(vm.deudoresFiltrados.map(\.id) == ["chico", "grande"])

        vm.orden = .fechaAscendente
        #expect(vm.deudoresFiltrados.map(\.id) == ["grande", "chico"])
    }

    @Test func busquedaFiltraPorNombreConDebounce() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.deudoresStub = [
            deudorPedido(id: "d1", nombre: "Ana García", monto: 100),
            deudorPedido(id: "d2", nombre: "Beto Pérez", monto: 200)
        ]
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { vm.deudores.count == 2 }

        vm.searchText = "ana"
        // El debounce es de 300 ms sobre RunLoop.main
        let filtrado = await esperarCondicion(iteraciones: 2_000) { vm.deudoresFiltrados.count == 1 }
        #expect(filtrado)
        #expect(vm.deudoresFiltrados.first?.id == "d1")
    }

    @Test func busquedaPorTipoYVencida() async {
        let finanzas = FinanzasRepositorioFake()
        finanzas.deudoresStub = [
            deudorPedido(id: "ped", nombre: "Ana", monto: 100),
            deudorInscripcion(id: "ins", nombre: "Beto", monto: 200) // fecha_curso 2025 < hoy → vencida
        ]
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { vm.deudores.count == 2 }

        vm.searchText = "inscripcion" // raw value del tipo
        var ok = await esperarCondicion(iteraciones: 2_000) { vm.deudoresFiltrados.map(\.id) == ["ins"] }
        #expect(ok)

        vm.searchText = "venc" // matchea deudores con estaVencida == true
        ok = await esperarCondicion(iteraciones: 2_000) { vm.deudoresFiltrados.map(\.id) == ["ins"] }
        #expect(ok)
    }

    @Test func fetchCronogramaItemDelegaAlTallerRepo() async {
        let taller = TallerRepositorioFake()
        taller.cronogramaItemStub = TestFactory.cronogramaItem(id: "c9")
        let vm = DeudoresViewModel(finanzasRepository: FinanzasRepositorioFake(), tallerRepository: taller)

        let item = await vm.fetchCronogramaItem(id: "c9")
        #expect(item?.id == "c9")
    }

    @Test func registrarPagoDelegaAlRepoYRefrescaLaLista() async throws {
        let finanzas = FinanzasRepositorioFake()
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { finanzas.fetchDeudoresLlamadas == 1 }

        let pedido = TestFactory.pedido(id: "p1")
        let pago = TestFactory.pago(origenID: "p1")

        try await vm.registrarPago(pago: pago, origen: .pedido(pedido), pagosSplit: nil)

        #expect(finanzas.registrarPagoLlamadas.count == 1)
        #expect(finanzas.fetchDeudoresLlamadas == 2)
    }

    @Test func registrarPagoConErrorNoRefrescaLaLista() async {
        let finanzas = FinanzasRepositorioFake()
        let vm = DeudoresViewModel(finanzasRepository: finanzas, tallerRepository: TallerRepositorioFake())
        _ = await esperarCondicion { finanzas.fetchDeudoresLlamadas == 1 }

        finanzas.errorStub = ErrorDePrueba()
        let pedido = TestFactory.pedido(id: "p1")
        let pago = TestFactory.pago(origenID: "p1")

        await #expect(throws: ErrorDePrueba.self) {
            try await vm.registrarPago(pago: pago, origen: .pedido(pedido), pagosSplit: nil)
        }
        #expect(finanzas.fetchDeudoresLlamadas == 1)
    }
}
