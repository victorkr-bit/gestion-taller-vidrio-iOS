import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("CursosViewModel — catálogo y CRUD")
struct CursosViewModelTests {

    @Test func emisionOrdenaCursosPorNombre() {
        let taller = TallerRepositorioFake()
        let vm = CursosViewModel(repository: taller)
        #expect(vm.isLoading)

        taller.emitirCursos([
            TestFactory.curso(id: "c1", nombre: "Vitrofusión"),
            TestFactory.curso(id: "c2", nombre: "Arte en vidrio")
        ])

        #expect(vm.cursos.map(\.nombre) == ["Arte en vidrio", "Vitrofusión"])
        #expect(!vm.isLoading)
    }

    @Test func errorDelListenerSeteaErrorMessage() {
        let taller = TallerRepositorioFake()
        let vm = CursosViewModel(repository: taller)
        taller.emitirErrorCursos(ErrorDePrueba())
        #expect(vm.errorMessage != nil)
    }

    @Test func saveCursoDevuelveContadoresDePropagacion() async {
        let taller = TallerRepositorioFake()
        taller.saveCursoStub = (cronogramas: 3, inscripciones: 7)
        let vm = CursosViewModel(repository: taller)

        let resultado = await vm.saveCurso(curso: TestFactory.curso(nombre: "Nuevo"))

        #expect(resultado?.cronogramas == 3)
        #expect(resultado?.inscripciones == 7)
        #expect(taller.saveCursoLlamadas.count == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test func saveCursoConErrorDevuelveNilYSeteaError() async {
        let taller = TallerRepositorioFake()
        taller.errorStub = ErrorDePrueba()
        let vm = CursosViewModel(repository: taller)

        let resultado = await vm.saveCurso(curso: TestFactory.curso())

        #expect(resultado == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test func deleteCursoBorraLosSeleccionadosEnParalelo() async {
        let taller = TallerRepositorioFake()
        let vm = CursosViewModel(repository: taller)
        taller.emitirCursos([
            TestFactory.curso(id: "c1", nombre: "A"),
            TestFactory.curso(id: "c2", nombre: "B"),
            TestFactory.curso(id: "c3", nombre: "C")
        ])

        vm.deleteCurso(at: IndexSet([0, 2])) // A y C

        let ok = await esperarCondicion { taller.deleteCursoLlamadas.count == 2 }
        #expect(ok)
        #expect(Set(taller.deleteCursoLlamadas.compactMap(\.id)) == ["c1", "c3"])
    }

    @Test func toggleVisibilidadOcultaUnCursoVisiblePorDefecto() async {
        let taller = TallerRepositorioFake()
        let vm = CursosViewModel(repository: taller)
        taller.emitirCursos([TestFactory.curso(id: "c1", nombre: "A")]) // visible_en_agenda == nil

        vm.toggleVisibilidad(curso: vm.cursos[0])

        let ok = await esperarCondicion { taller.actualizarVisibilidadCursoLlamadas.count == 1 }
        #expect(ok)
        #expect(taller.actualizarVisibilidadCursoLlamadas.first?.cursoId == "c1")
        #expect(taller.actualizarVisibilidadCursoLlamadas.first?.visible == false)
        #expect(vm.cursos.first?.visible_en_agenda == false)
    }

    @Test func toggleVisibilidadReactivaUnCursoOculto() async {
        let taller = TallerRepositorioFake()
        let vm = CursosViewModel(repository: taller)
        taller.emitirCursos([TestFactory.curso(id: "c1", nombre: "A", visibleEnAgenda: false)])

        vm.toggleVisibilidad(curso: vm.cursos[0])

        let ok = await esperarCondicion { taller.actualizarVisibilidadCursoLlamadas.count == 1 }
        #expect(ok)
        #expect(taller.actualizarVisibilidadCursoLlamadas.first?.visible == true)
        #expect(vm.cursos.first?.visible_en_agenda == true)
    }

    @Test func toggleVisibilidadConErrorSeteaErrorMessage() async {
        let taller = TallerRepositorioFake()
        taller.errorStub = ErrorDePrueba()
        let vm = CursosViewModel(repository: taller)
        taller.emitirCursos([TestFactory.curso(id: "c1")])

        vm.toggleVisibilidad(curso: vm.cursos[0])

        let ok = await esperarCondicion { vm.errorMessage != nil }
        #expect(ok)
    }
}
