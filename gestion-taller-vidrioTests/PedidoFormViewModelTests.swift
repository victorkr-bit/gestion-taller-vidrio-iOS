import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("PedidoFormViewModel — validación y guardado dual")
struct PedidoFormViewModelTests {

    private func makeVM(pedido: Pedido? = nil) -> (vm: PedidoFormViewModel, ventas: VentasRepositorioFake, contactos: ContactosRepositorioFake) {
        let ventas = VentasRepositorioFake()
        let contactos = ContactosRepositorioFake()
        let vm = PedidoFormViewModel(pedido: pedido, repository: ventas, contactosRepo: contactos)
        return (vm, ventas, contactos)
    }

    @Test func isValidExigeClienteDescripcionYPresupuestoNoNegativo() {
        let (vm, _, _) = makeVM()

        #expect(!vm.isValid) // todo vacío

        vm.clienteId = "c1"
        vm.descripcion = "   " // solo espacios
        #expect(!vm.isValid)

        vm.descripcion = "Vitral"
        vm.presupuesto = -1
        #expect(!vm.isValid)

        vm.presupuesto = 0 // cero es válido
        #expect(vm.isValid)
    }

    @Test func modoCreacionArrancaVacio() {
        let (vm, _, _) = makeVM()
        #expect(!vm.isEditing)
        #expect(vm.clienteId.isEmpty)
        #expect(vm.presupuesto == 0)
    }

    @Test func modoEdicionPueblaDesdeElPedido() {
        let original = TestFactory.pedido(
            id: "p9", presupuesto: 8_000, tipo: .joyeria,
            cliente: "Ana", descripcion: "Anillo", montoAbonado: 2_000, estadoEntrega: true
        )
        let (vm, _, _) = makeVM(pedido: original)

        #expect(vm.isEditing)
        #expect(vm.clienteNombre == "Ana")
        #expect(vm.descripcion == "Anillo")
        #expect(vm.presupuesto == 8_000)
        #expect(vm.tipo == .joyeria)
        #expect(vm.estadoEntrega)
        #expect(vm.montoAbonadoOriginal == 2_000)
    }

    @Test func guardarCreacionLlamaSinExistingIDYDescarta() async {
        let (vm, ventas, _) = makeVM()
        vm.clienteId = "c1"
        vm.clienteNombre = "Ana"
        vm.descripcion = "  Vitral redondo  " // con espacios

        vm.guardar()

        let ok = await esperarCondicion { vm.shouldDismiss }
        #expect(ok)
        #expect(ventas.savePedidoLlamadas.count == 1)
        #expect(ventas.savePedidoLlamadas.first?.existingID == nil)
        #expect(ventas.savePedidoLlamadas.first?.pedido.descripcion == "Vitral redondo") // trimmed
        #expect(!vm.isLoading)
    }

    @Test func guardarEdicionPasaElIDExistente() async {
        let original = TestFactory.pedido(id: "p9", cliente: "Ana")
        let (vm, ventas, _) = makeVM(pedido: original)

        vm.guardar()

        let ok = await esperarCondicion { ventas.savePedidoLlamadas.count == 1 }
        #expect(ok)
        #expect(ventas.savePedidoLlamadas.first?.existingID == "p9")
    }

    @Test func guardarInvalidoNoLlamaAlRepo() async {
        let (vm, ventas, _) = makeVM()
        // clienteId vacío → inválido

        vm.guardar()

        let llamado = await esperarCondicion(iteraciones: 50) { !ventas.savePedidoLlamadas.isEmpty }
        #expect(!llamado)
        #expect(!vm.shouldDismiss)
    }

    @Test func errorDelRepoSeteaErrorYNoDescarta() async {
        let (vm, ventas, _) = makeVM()
        ventas.errorStub = ErrorDePrueba()
        vm.clienteId = "c1"
        vm.descripcion = "Vitral"

        vm.guardar()

        let fallo = await esperarCondicion { vm.errorMessage != nil }
        #expect(fallo)
        #expect(!vm.shouldDismiss)
        #expect(!vm.isLoading)
    }

    @Test func fetchContactosPueblaLista() async {
        let (vm, _, contactos) = makeVM()
        contactos.contactosStub = [TestFactory.contacto(id: "c1", nombre: "Ana")]

        vm.fetchContactos()

        let ok = await esperarCondicion { vm.contactos.count == 1 }
        #expect(ok)
    }
}
