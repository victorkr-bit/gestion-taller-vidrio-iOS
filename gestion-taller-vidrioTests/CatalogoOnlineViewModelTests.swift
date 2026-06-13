import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("CatalogoOnlineViewModel — listener on-demand")
struct CatalogoOnlineViewModelTests {

    @Test func noEscuchaHastaSubscribe() {
        let taller = TallerRepositorioFake()
        let vm = CatalogoOnlineViewModel(tallerRepo: taller)

        #expect(taller.catalogoOnlineCompletion == nil)
        #expect(vm.catalogoOnline.isEmpty)
    }

    @Test func subscribeEmiteOrdenadoPorNombre() {
        let taller = TallerRepositorioFake()
        let vm = CatalogoOnlineViewModel(tallerRepo: taller)

        vm.subscribeToCatalogoOnline()
        #expect(vm.isLoading)

        taller.emitirCatalogoOnline([
            TestFactory.curso(id: "c1", nombre: "Zen del vidrio", tipo: .online),
            TestFactory.curso(id: "c2", nombre: "Arte online", tipo: .online)
        ])

        #expect(vm.catalogoOnline.map(\.nombre) == ["Arte online", "Zen del vidrio"])
        #expect(!vm.isLoading)
    }

    @Test func errorSeteaErrorMessage() {
        let taller = TallerRepositorioFake()
        let vm = CatalogoOnlineViewModel(tallerRepo: taller)
        vm.subscribeToCatalogoOnline()

        taller.emitirErrorCatalogo(ErrorDePrueba())

        #expect(vm.errorMessage != nil)
    }

    @Test func stopListeningCancelaElListener() {
        let taller = TallerRepositorioFake()
        let vm = CatalogoOnlineViewModel(tallerRepo: taller)
        vm.subscribeToCatalogoOnline()

        vm.stopListening()

        #expect(taller.cancelacionesCatalogo == 1)
    }

    @Test func resubscribeCancelaElListenerAnterior() {
        let taller = TallerRepositorioFake()
        let vm = CatalogoOnlineViewModel(tallerRepo: taller)

        vm.subscribeToCatalogoOnline()
        vm.subscribeToCatalogoOnline()

        #expect(taller.cancelacionesCatalogo == 1) // el primero se removió
    }
}
