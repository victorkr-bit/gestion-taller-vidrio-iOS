import SwiftUI

struct AgendaListView: View {
    @ObservedObject var agendaVM: AgendaViewModel
    @ObservedObject var inscripcionesVM: InscripcionesViewModel
    @EnvironmentObject var navManager: NavigationManager

    @Binding var itemToEdit: CronogramaItem?
    @Binding var itemToDelete: CronogramaItem?
    @Binding var showDeleteAlert: Bool
    @Binding var itemToMover: CronogramaItem?

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
                                VStack(alignment: .leading, spacing: DesignSystem.Espaciado.xs) {
                                    HStack(spacing: DesignSystem.Espaciado.xs) {
                                        Text(item.cursoNombre)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if item.es_profesor_externo == true {
                                            Image(systemName: "figure.walk.suitcase.rolling.circle")
                                                .foregroundStyle(.orange)
                                                .accessibilityLabel("Profesor externo")
                                        }
                                    }

                                    HStack {
                                        Label(
                                            "\(Formatters.date(item.fecha))  •  \(item.hora_inicio ?? Formatters.time(item.fecha))",
                                            systemImage: "calendar"
                                        )
                                        Spacer()
                                        if item.cursoTipo == .presencial {
                                            let pre = inscripcionesVM.preinscriptosPorCronograma[item.id ?? "", default: 0]
                                            Label(item.textoInscriptos(preinscriptos: pre), systemImage: "person.2.fill")
                                        } else {
                                            Label("\(item.inscriptosReales)", systemImage: "person.2.fill")
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(DesignSystem.Color.accion)
                                }
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
                            Button {
                                itemToMover = item
                            } label: {
                                Label("Mover fecha", systemImage: "calendar.badge.plus")
                            }
                            if let url = item.inscripcionURL {
                                Button {
                                    UIPasteboard.general.string = url.absoluteString
                                } label: {
                                    Label("Copiar link de inscripción", systemImage: "link")
                                }
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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                itemToMover = item
                            } label: {
                                Label("Mover fecha", systemImage: "calendar.badge.plus")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { agendaVM.fetchCronograma() }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AgendaListView(agendaVM: PreviewContainer.shared.agendaVM,
                       inscripcionesVM: PreviewContainer.shared.inscripcionesVM,
                       itemToEdit: .constant(nil), itemToDelete: .constant(nil),
                       showDeleteAlert: .constant(false), itemToMover: .constant(nil))
    }
    .environmentObject(NavigationManager())
}
#endif
