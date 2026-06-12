import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("PagosViewModel — filtros, totales y período")
struct PagosViewModelTests {

    private func makeVM() -> (vm: PagosViewModel, finanzas: FinanzasRepositorioFake) {
        let finanzas = FinanzasRepositorioFake()
        let vm = PagosViewModel(finanzasRepo: finanzas, contactosRepo: ContactosRepositorioFake())
        return (vm, finanzas)
    }

    @Test func emisionDelListenerPueblaPagos() {
        let (vm, finanzas) = makeVM()
        #expect(vm.isLoading)

        finanzas.emitirPagos([TestFactory.pago(id: "a"), TestFactory.pago(id: "b")])

        #expect(vm.pagos.count == 2)
        #expect(!vm.isLoading)
    }

    @Test func busquedaCubreTextoYTags() {
        let (vm, finanzas) = makeVM()
        finanzas.emitirPagos([
            TestFactory.pago(id: "a", medio: .efectivo, tipoVenta: .taller, cliente: "Ana García",
                             notas: "seña vitral", descripcionOrigen: "Pedido #P-0100"),
            TestFactory.pago(id: "b", medio: .transferencia, tipoVenta: .piezas, cliente: "Beto Pérez",
                             notas: nil, descripcionOrigen: "Inscripción Taller X")
        ])

        vm.searchText = "ana" // cliente
        #expect(vm.pagosFiltrados.map(\.id) == ["a"])

        vm.searchText = "p-0100" // descripción de origen
        #expect(vm.pagosFiltrados.map(\.id) == ["a"])

        vm.searchText = "seña" // notas
        #expect(vm.pagosFiltrados.map(\.id) == ["a"])

        vm.searchText = MedioDePago.transferencia.rawValue.lowercased() // tag medio de pago
        #expect(vm.pagosFiltrados.map(\.id) == ["b"])

        vm.searchText = TipoVenta.piezas.descripcion.lowercased() // tag tipo de venta
        #expect(vm.pagosFiltrados.map(\.id) == ["b"])

        vm.searchText = ""
        #expect(vm.pagosFiltrados.count == 2)
    }

    @Test func totalFiltradoSumaSoloLoVisible() {
        let (vm, finanzas) = makeVM()
        finanzas.emitirPagos([
            TestFactory.pago(id: "a", monto: 1_000, cliente: "Ana"),
            TestFactory.pago(id: "b", monto: 600, cliente: "Beto"),
            TestFactory.pago(id: "c", monto: 50, cliente: "Ana")
        ])

        #expect(vm.totalFiltrado == 1_650)

        vm.searchText = "ana"
        #expect(vm.totalFiltrado == 1_050)
    }

    @Test func periodoLabelSegunRango() {
        let (vm, _) = makeVM()

        vm.mesInicio = MesAño(mes: 7, año: 2025)
        vm.mesFin = MesAño(mes: 7, año: 2025)
        #expect(vm.periodoLabel == MesAño(mes: 7, año: 2025).shortLabel) // "Jul 2025"

        vm.mesInicio = MesAño(mes: 3, año: 2025)
        vm.mesFin = MesAño(mes: 5, año: 2025)
        #expect(vm.periodoLabel == "Mar – \(MesAño(mes: 5, año: 2025).shortLabel)")

        vm.mesInicio = MesAño(mes: 11, año: 2024)
        vm.mesFin = MesAño(mes: 2, año: 2025)
        #expect(vm.periodoLabel == "\(MesAño(mes: 11, año: 2024).shortLabel) – \(MesAño(mes: 2, año: 2025).shortLabel)")
    }

    @Test func cambiarMesReiniciaListenerConNuevoRango() {
        let (vm, finanzas) = makeVM()
        let llamadasIniciales = finanzas.rangosRecibidos.count

        let nuevo = MesAño(mes: 1, año: 2025)
        vm.mesInicio = nuevo

        #expect(finanzas.rangosRecibidos.count == llamadasIniciales + 1)
        #expect(finanzas.ultimoRango?.from == nuevo.fechaInicio)
    }

    @Test func sincronizarMesActualResetea() {
        let (vm, _) = makeVM()
        vm.mesInicio = MesAño(mes: 1, año: 2020)
        vm.mesFin = MesAño(mes: 2, año: 2020)

        vm.sincronizarMesActualSiCambio()

        #expect(vm.mesInicio == MesAño.current())
        #expect(vm.mesFin == MesAño.current())
    }

    @Test func errorDelListenerSeteaErrorMessage() {
        let (vm, finanzas) = makeVM()
        finanzas.emitirErrorPagos(ErrorDePrueba())
        #expect(vm.errorMessage != nil)
        #expect(!vm.isLoading)
    }

    @Test func ventaDirectaConArgumentosArmaPagoYDelega() async {
        let (vm, finanzas) = makeVM()

        vm.saveVentaDirecta(monto: 800, medioPago: .efectivo, notas: "mostrador", cliente: nil)

        let llamado = await esperarCondicion { finanzas.ventaDirectaLlamadas.count == 1 }
        #expect(llamado)
        let pago = finanzas.ventaDirectaLlamadas.first
        #expect(pago?.monto == 800)
        #expect(pago?.cliente_nombre == "Consumidor Final")
        #expect(pago?.origen_tipo == .ventaDirecta)
        #expect(pago?.origen_id == nil)
    }

    @Test func deleteYEditDeleganAlRepo() async {
        let (vm, finanzas) = makeVM()
        let pago = TestFactory.pago(id: "x", monto: 500)

        vm.deletePago(pago)
        vm.savePagoEditado(pago: pago, montoAntiguo: 300)

        let ok = await esperarCondicion {
            finanzas.deletePagoLlamadas.count == 1 && finanzas.editPagoLlamadas.count == 1
        }
        #expect(ok)
        #expect(finanzas.editPagoLlamadas.first?.montoAntiguo == 300)
    }
}
