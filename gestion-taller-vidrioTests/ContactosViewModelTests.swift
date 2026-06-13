import Foundation
import Testing
@testable import gestion_taller_vidrio

@Suite("ContactosViewModel — lista, búsqueda y CRUD")
struct ContactosViewModelTests {

    @Test func initCargaContactosOrdenadosConForceRefresh() async {
        let repo = ContactosRepositorioFake()
        repo.contactosStub = [
            TestFactory.contacto(id: "c1", nombre: "Zoe", apellido: "Ruiz"),
            TestFactory.contacto(id: "c2", nombre: "Ana", apellido: "García")
        ]
        let vm = ContactosViewModel(repository: repo)

        let cargado = await esperarCondicion { vm.contactos.count == 2 }
        #expect(cargado)
        #expect(vm.contactos.map(\.nombre) == ["Ana", "Zoe"])
        #expect(repo.fetchContactosLlamadas.first == true) // forceRefresh
        #expect(!vm.isLoading)
    }

    @Test func errorDelFetchSeteaErrorMessage() async {
        let repo = ContactosRepositorioFake()
        repo.errorStub = ErrorDePrueba()
        let vm = ContactosViewModel(repository: repo)

        let fallo = await esperarCondicion { vm.errorMessage != nil }
        #expect(fallo)
        #expect(vm.contactos.isEmpty)
    }

    @Test func contactosFiltradosBuscaPorNombreCompleto() async {
        let repo = ContactosRepositorioFake()
        repo.contactosStub = [
            TestFactory.contacto(id: "c1", nombre: "Ana", apellido: "García"),
            TestFactory.contacto(id: "c2", nombre: "Beto", apellido: "Pérez")
        ]
        let vm = ContactosViewModel(repository: repo)
        _ = await esperarCondicion { vm.contactos.count == 2 }

        vm.searchText = "garcía" // case-insensitive, matchea apellido
        #expect(vm.contactosFiltrados.map(\.id) == ["c1"])

        vm.searchText = "beto p" // nombre completo
        #expect(vm.contactosFiltrados.map(\.id) == ["c2"])

        vm.searchText = ""
        #expect(vm.contactosFiltrados.count == 2)
    }

    @Test func saveContactoDelegaYRefresca() async {
        let repo = ContactosRepositorioFake()
        let vm = ContactosViewModel(repository: repo)
        _ = await esperarCondicion { !repo.fetchContactosLlamadas.isEmpty }
        let fetchesIniciales = repo.fetchContactosLlamadas.count

        let nuevo = TestFactory.contacto(id: nil, nombre: "Carla", apellido: "López")
        try? await vm.saveContactoAsync(datos: nuevo, id: "uid-123")

        #expect(repo.saveContactoLlamadas.count == 1)
        #expect(repo.saveContactoLlamadas.first?.uid == "uid-123")
        let refrescado = await esperarCondicion { repo.fetchContactosLlamadas.count > fetchesIniciales }
        #expect(refrescado)
    }

    @Test func updateContactoDelegaConID() async throws {
        let repo = ContactosRepositorioFake()
        let vm = ContactosViewModel(repository: repo)

        try await vm.updateContactoAsync(datos: TestFactory.contacto(nombre: "Editado"), id: "c1")

        #expect(repo.updateContactoLlamadas.count == 1)
        #expect(repo.updateContactoLlamadas.first?.id == "c1")
        #expect(repo.updateContactoLlamadas.first?.contacto.nombre == "Editado")
    }

    @Test func deleteContactoUsaLaListaFiltrada() async {
        let repo = ContactosRepositorioFake()
        repo.contactosStub = [
            TestFactory.contacto(id: "c1", nombre: "Ana", apellido: "García"),
            TestFactory.contacto(id: "c2", nombre: "Beto", apellido: "Pérez")
        ]
        let vm = ContactosViewModel(repository: repo)
        _ = await esperarCondicion { vm.contactos.count == 2 }

        // Con filtro activo, el offset 0 apunta al primer FILTRADO (Beto), no al primero global (Ana)
        vm.searchText = "beto"
        vm.deleteContacto(at: IndexSet([0]))

        let borrado = await esperarCondicion { repo.deleteContactoLlamadas.count == 1 }
        #expect(borrado)
        #expect(repo.deleteContactoLlamadas.first?.id == "c2")
    }
}
