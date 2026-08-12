import SwiftUI

struct CursosView: View {

    @StateObject private var viewModel: CursosViewModel

    init(tallerRepo: any TallerRepositorio) {
        _viewModel = StateObject(wrappedValue: CursosViewModel(repository: tallerRepo))
    }

    @State private var cursoToEdit: Curso?
    @State private var isCreatingNew = false
    @State private var cursoToDelete: Curso?
    @State private var archivadosExpandido = false

    private var cursosActivos: [Curso] {
        viewModel.cursos.filter { $0.visible_en_agenda ?? true }
    }

    private var cursosArchivados: [Curso] {
        viewModel.cursos.filter { $0.visible_en_agenda == false }
    }

    private func cursos(de tipo: TipoCurso) -> [Curso] {
        cursosActivos.filter { $0.tipo == tipo }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.cursos.isEmpty {
                    ProgressView("Cargando cursos...")
                } else {
                    List {
                        ForEach(TipoCurso.allCases) { tipo in
                            let cursosDelTipo = cursos(de: tipo)
                            if !cursosDelTipo.isEmpty {
                                Section(tipo.descripcion) {
                                    ForEach(cursosDelTipo) { curso in
                                        CursoRowView(curso: curso, viewModel: viewModel) {
                                            cursoToEdit = curso
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                cursoToDelete = curso
                                            } label: {
                                                Label("Eliminar", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !cursosArchivados.isEmpty {
                            DisclosureGroup("Archivados (\(cursosArchivados.count))", isExpanded: $archivadosExpandido) {
                                ForEach(cursosArchivados) { curso in
                                    CursoRowView(curso: curso, viewModel: viewModel) {
                                        cursoToEdit = curso
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            cursoToDelete = curso
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.startListening()
                    }
                }
            }
            .navigationTitle("Catálogo de Cursos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.isCreatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            .sheet(isPresented: $isCreatingNew) {
                NavigationStack {
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: nil
                    )
                }
            }

            .sheet(item: $cursoToEdit) { curso in
                NavigationStack {
                    CursoFormView(
                        viewModel: viewModel,
                        cursoToEdit: curso
                    )
                }
            }

            .errorAlert($viewModel.errorMessage)
            .alert("Eliminar Curso", isPresented: Binding<Bool>(
                get: { cursoToDelete != nil },
                set: { if !$0 { cursoToDelete = nil } }
            )) {
                Button("Eliminar", role: .destructive) {
                    if let curso = cursoToDelete, let index = viewModel.cursos.firstIndex(where: { $0.id == curso.id }) {
                        viewModel.deleteCurso(at: IndexSet(integer: index))
                    }
                    cursoToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    cursoToDelete = nil
                }
            } message: {
                Text("¿Eliminar \"\(cursoToDelete?.nombre ?? "")\"? Esta acción no se puede deshacer.")
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CursosView(tallerRepo: PreviewContainer.shared.tallerRepo)
    }
    .environmentObject(NavigationManager())
}
#endif
