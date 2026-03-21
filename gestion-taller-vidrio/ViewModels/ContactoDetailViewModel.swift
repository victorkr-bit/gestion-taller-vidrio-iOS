import Foundation
import Combine

@MainActor
final class ContactoDetailViewModel: ObservableObject {

    @Published var inscripciones: [Inscripcion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tallerRepo: TallerRepository

    init(tallerRepo: TallerRepository = TallerRepository()) {
        self.tallerRepo = tallerRepo
    }

    func cargar(alumnoId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let resultado = try await tallerRepo.fetchInscripcionesByAlumno(alumnoId: alumnoId)
            inscripciones = resultado.sorted { $0.fecha_curso > $1.fecha_curso }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
