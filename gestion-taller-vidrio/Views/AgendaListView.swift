import SwiftUI

struct AgendaListView: View {
    @ObservedObject var agendaVM: AgendaViewModel
    @EnvironmentObject var navManager: NavigationManager

    @Binding var itemToEdit: CronogramaItem?
    @Binding var itemToDelete: CronogramaItem?
    @Binding var showDeleteAlert: Bool

    var body: some View {
        ZStack {
            if agendaVM.isLoading && agendaVM.cursosFiltrados.isEmpty {
                ProgressView("Cargando agenda...")
            } else if agendaVM.cursosFiltrados.isEmpty {
                ContentUnavailableView("No hay eventos", systemImage: "calendar.badge.exclamationmark")
            } else {
                List {
                    ForEach(agendaVM.cursosFiltrados) { item in
                        Button {
                            navManager.cronogramaPath.append(item)
                        } label: {
                            CardView {
                                GenericRowView(
                                    titulo: item.cursoNombre,
                                    subtitulo: nil,
                                    infoSuperior: Formatters.date(item.fecha),
                                    infoSuperiorSecundaria: Formatters.time(item.fecha),
                                    iconoSuperior: "calendar",
                                    monto: item.precio_curso,
                                    tags: [
                                        TagConfig(
                                            text: "Alumnos (\(item.inscriptosReales))",
                                            color: item.inscriptosReales > 0 ? .blue : .gray
                                        )
                                    ]
                                )
                            }
                        }
                        .listRowSeparator(.hidden)
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Editar Curso", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Eliminar Curso", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Borrar", systemImage: "trash.fill")
                            }
                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { agendaVM.fetchCronograma() }
            }
        }
    }
}
