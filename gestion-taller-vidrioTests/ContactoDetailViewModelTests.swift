import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("ContactoDetailViewModel — historial de inscripciones")
struct ContactoDetailViewModelTests {

    @Test func cargarOrdenaPorFechaDeCursoDescendente() async {
        let taller = TallerRepositorioFake()
        let vieja = Date(timeIntervalSince1970: 1_700_000_000)
        let nueva = Date(timeIntervalSince1970: 1_760_000_000)
        taller.inscripcionesStub = [
            TestFactory.inscripcion(id: "i-vieja", fechaCurso: vieja),
            TestFactory.inscripcion(id: "i-nueva", fechaCurso: nueva)
        ]
        let vm = ContactoDetailViewModel(tallerRepo: taller)

        await vm.cargar(alumnoId: "alumno-7")

        #expect(vm.inscripciones.map(\.id) == ["i-nueva", "i-vieja"])
        #expect(taller.fetchInscripcionesByAlumnoLlamadas == ["alumno-7"])
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
    }

    @Test func errorDelRepoSeteaErrorMessage() async {
        let taller = TallerRepositorioFake()
        taller.errorStub = ErrorDePrueba()
        let vm = ContactoDetailViewModel(tallerRepo: taller)

        await vm.cargar(alumnoId: "alumno-7")

        #expect(vm.errorMessage != nil)
        #expect(vm.inscripciones.isEmpty)
        #expect(!vm.isLoading)
    }

    @Test func sinInscripcionesQuedaListaVacia() async {
        let taller = TallerRepositorioFake()
        let vm = ContactoDetailViewModel(tallerRepo: taller)

        await vm.cargar(alumnoId: "alumno-7")

        #expect(vm.inscripciones.isEmpty)
        #expect(vm.errorMessage == nil)
    }
}
