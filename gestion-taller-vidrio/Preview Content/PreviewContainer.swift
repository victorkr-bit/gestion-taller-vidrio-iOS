#if DEBUG
import SwiftUI
import Combine

/// Espejo de `AppContainer` para previews (solo DEBUG): mismo wiring de VMs pero
/// con repos de preview auto-emisores. Usar `PreviewContainer.shared` en los
/// bloques `#Preview`.
@MainActor
final class PreviewContainer: ObservableObject {
    static let shared = PreviewContainer()

    // MARK: - Repositorios
    let finanzasRepo: FinanzasRepositorioPreview
    let tallerRepo: TallerRepositorioPreview
    let ventasRepo: VentasRepositorioPreview
    let contactosRepo: ContactosRepositorioPreview

    // MARK: - Coordinadores
    let filterCoordinator: FilterCoordinator

    // MARK: - ViewModels
    let metricasVM: MetricasViewModel
    let chartsVM: ChartsViewModel
    let proximaActividadVM: ProximaActividadViewModel
    let pagosVM: PagosViewModel
    let agendaVM: AgendaViewModel
    let inscripcionesVM: InscripcionesViewModel
    let catalogoOnlineVM: CatalogoOnlineViewModel
    let pedidosVM: PedidosViewModel
    let deudoresVM: DeudoresViewModel
    let contactoDetailVM: ContactoDetailViewModel

    init() {
        let finanzasRepo = FinanzasRepositorioPreview()
        let tallerRepo = TallerRepositorioPreview()
        let ventasRepo = VentasRepositorioPreview()
        let contactosRepo = ContactosRepositorioPreview()

        self.finanzasRepo = finanzasRepo
        self.tallerRepo = tallerRepo
        self.ventasRepo = ventasRepo
        self.contactosRepo = contactosRepo

        let filterCoordinator = FilterCoordinator()
        self.filterCoordinator = filterCoordinator

        self.metricasVM = MetricasViewModel(
            finanzasRepo: finanzasRepo,
            filter: filterCoordinator
        )
        self.chartsVM = ChartsViewModel(
            finanzasRepo: finanzasRepo,
            tallerRepo: tallerRepo,
            filter: filterCoordinator
        )
        self.proximaActividadVM = ProximaActividadViewModel(tallerRepo: tallerRepo)

        self.pagosVM = PagosViewModel(
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        self.agendaVM = AgendaViewModel(tallerRepo: tallerRepo)
        self.catalogoOnlineVM = CatalogoOnlineViewModel(tallerRepo: tallerRepo)
        self.inscripcionesVM = InscripcionesViewModel(
            tallerRepo: tallerRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        self.pedidosVM = PedidosViewModel(
            ventasRepo: ventasRepo,
            finanzasRepo: finanzasRepo,
            contactosRepo: contactosRepo
        )

        self.deudoresVM = DeudoresViewModel(finanzasRepository: finanzasRepo, tallerRepository: tallerRepo)

        self.contactoDetailVM = ContactoDetailViewModel(tallerRepo: tallerRepo)
    }
}
#endif
