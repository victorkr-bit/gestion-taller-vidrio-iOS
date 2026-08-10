import Foundation
import Combine
import SwiftUI

private let bsasCalendarVM: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
    return cal
}()

private struct NolaborableDTO: Decodable {
    let fecha: String
}

private struct NagerFeriadoDTO: Decodable {
    let date: String
}

private struct HebcalResponse: Decodable {
    let items: [HebcalItemDTO]
}
private struct HebcalItemDTO: Decodable {
    let title: String
    let date: String
}

@MainActor
class AgendaViewModel: ObservableObject {

    // MARK: - Estado de la Vista
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Lógica de Filtro
    @Published private(set) var cursosProximos: [CronogramaItem] = []
    @Published private(set) var cursosHistoricos: [CronogramaItem] = []

    // Caché de feriados (por año, persistente en sesión)
    @Published private(set) var feriadosCalendario: Set<DateComponents> = []
    @Published private(set) var fiestasJudias: Set<DateComponents> = []
    private var feriadosLoaded = false

    enum FiltroCronograma: String, CaseIterable, Identifiable {
        case proximos = "Próximos"
        case historial = "Historial"
        var id: String { self.rawValue }
    }

    @Published var filtroSeleccionado: FiltroCronograma = .proximos

    var cursosFiltrados: [CronogramaItem] {
        switch filtroSeleccionado {
        case .proximos: return cursosProximos
        case .historial: return cursosHistoricos
        }
    }

    // Catálogo de cursos (para picker en AgendaFormView)
    @Published var cursos: [Curso] = []

    // Listener
    private var cronogramaListener: SuscripcionActiva?
    private let taskTracker = TaskTracker()

    // Día (inicio del día en Argentina) en el que se armó la suscripción actual.
    // Sirve para detectar el cruce de medianoche con la app abierta y recomputar el corte.
    private var diaSuscripcion: Date?

    // MARK: - Dependencia
    private let tallerRepo: any TallerRepositorio

    init(tallerRepo: any TallerRepositorio) {
        self.tallerRepo = tallerRepo
        subscribeToCronograma()
    }

    isolated deinit {
        cronogramaListener?.remove()
    }

    // MARK: - Lógica Reactiva

    /// Recomputa el corte de "hoy" y re-suscribe solo si cambió el día.
    /// Necesario porque el corte queda capturado al armar el listener: con la app
    /// abierta cruzando medianoche, los cursos de ayer no migran a históricos hasta reiniciar.
    func refrescarSiCambioDia() {
        if inicioDiaArgentina() != diaSuscripcion {
            subscribeToCronograma()
        }
    }

    private func inicioDiaArgentina() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires") ?? .current
        return cal.startOfDay(for: Date())
    }

    func subscribeToCronograma() {
        isLoading = true
        errorMessage = nil
        diaSuscripcion = inicioDiaArgentina()

        cronogramaListener?.remove()

        cronogramaListener = tallerRepo.listenToCursosProximos { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let items):
                self.cursosProximos = items
            case .failure(let error):
                self.errorMessage = "Error sincronizando cronograma: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        }

        // Fetch de HISTORIAL (One-Shot)
        taskTracker.track(Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error cargando historial: \(FirestoreManager.mensajeAmigable(error))"
                self.isLoading = false
            }
        })
    }

    func fetchCronograma() {
        // Recarga manual del historial
        taskTracker.track(Task {
            do {
                self.cursosHistoricos = try await tallerRepo.fetchCursosHistoricos()
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error actualizando historial: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func fetchCursos() {
        taskTracker.track(Task {
            do {
                self.cursos = try await tallerRepo.fetchCursos()
                    .sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending }
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error al cargar el catálogo de cursos: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    // MARK: - Feriados (caché por sesión)

    func fetchFeriadosIfNeeded() async {
        guard !feriadosLoaded else { return }
        feriadosLoaded = true
        let ahora = Date()
        let inicioMes = bsasCalendarVM.date(from: bsasCalendarVM.dateComponents([.year, .month], from: ahora))!
        let años = Set((0..<4).compactMap { offset -> Int? in
            guard let mes = bsasCalendarVM.date(byAdding: .month, value: offset, to: inicioMes) else { return nil }
            return bsasCalendarVM.component(.year, from: mes)
        })
        var todosFeriados: Set<DateComponents> = []
        var todasJudias: Set<DateComponents> = []
        for año in años {
            todosFeriados.formUnion(await fetchNolaborables(año: año))
            todasJudias.formUnion(await fetchHebcal(año: año))
        }
        feriadosCalendario = todosFeriados
        fiestasJudias = todasJudias
    }

    private func fetchNolaborables(año: Int) async -> Set<DateComponents> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")

        func parseDate(_ str: String) -> DateComponents? {
            guard let date = fmt.date(from: str) else { return nil }
            let raw = bsasCalendarVM.dateComponents([.year, .month, .day], from: date)
            var c = DateComponents()
            c.year = raw.year; c.month = raw.month; c.day = raw.day
            return c
        }

        // Fuente principal: argentinadatos (incluye puentes turísticos)
        if let url = URL(string: "https://api.argentinadatos.com/v1/feriados/\(año)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let lista = try? JSONDecoder().decode([NolaborableDTO].self, from: data),
           !lista.isEmpty {
            return Set(lista.compactMap { parseDate($0.fecha) })
        }

        // Fallback: nager.date (feriados inamovibles, sin puentes turísticos)
        guard let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(año)/AR"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let lista = try? JSONDecoder().decode([NagerFeriadoDTO].self, from: data)
        else { return [] }

        return Set(lista.compactMap { parseDate($0.date) })
    }

    private func fetchHebcal(año: Int) async -> Set<DateComponents> {
        let urlStr = "https://www.hebcal.com/hebcal?v=1&cfg=json&maj=on&min=off&nx=off&mf=off&ss=off&mod=off&year=\(año)&i=off&geo=none"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let resp = try? JSONDecoder().decode(HebcalResponse.self, from: data)
        else { return [] }

        let titulosDeseados = ["Rosh Hashana", "Yom Kippur", "Pesach I", "Pesach II"]
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")

        return Set(resp.items.compactMap { item -> DateComponents? in
            guard titulosDeseados.contains(where: { item.title.hasPrefix($0) }),
                  let date = fmt.date(from: String(item.date.prefix(10)))
            else { return nil }
            let raw = bsasCalendarVM.dateComponents([.year, .month, .day], from: date)
            var c = DateComponents()
            c.year = raw.year; c.month = raw.month; c.day = raw.day
            return c
        })
    }

    // MARK: - CRUD Cronograma

    func saveCronogramaItem(item: CronogramaItem) {
        taskTracker.track(Task {
            do {
                try await tallerRepo.saveCronogramaItem(item: item)
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                self.errorMessage = "Error al guardar el curso programado: \(FirestoreManager.mensajeAmigable(error))"
            }
        })
    }

    func item(for id: String) -> CronogramaItem? {
        cursosProximos.first { $0.id == id } ?? cursosHistoricos.first { $0.id == id }
    }

    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?, nuevoCupo: Int?, horaInicio: String? = nil, horaFin: String? = nil) async throws {
        errorMessage = nil
        try await tallerRepo.actualizarCronograma(id: id, nuevoPrecio: nuevoPrecio, nuevaFecha: nuevaFecha, nuevasNotas: nuevasNotas, nuevoCupo: nuevoCupo, horaInicio: horaInicio, horaFin: horaFin)

        // Actualización local inmediata para que la UI refleje los cambios
        // sin esperar al listener (que además no cubre históricos).
        let aplicar = { (item: inout CronogramaItem) in
            if let precio = nuevoPrecio { item.precio_curso = precio }
            if let fecha = nuevaFecha { item.fecha = fecha }
            if let notas = nuevasNotas { item.notas = notas }
            if let cupo = nuevoCupo { item.cupo_maximo = cupo == 0 ? nil : cupo }
            if let h = horaInicio { item.hora_inicio = h }
            if let h = horaFin { item.hora_fin = h }
        }
        if let idx = cursosProximos.firstIndex(where: { $0.id == id }) {
            aplicar(&cursosProximos[idx])
        }
        if let idx = cursosHistoricos.firstIndex(where: { $0.id == id }) {
            aplicar(&cursosHistoricos[idx])
        }
    }

    func deleteCronogramaItem(_ item: CronogramaItem) {
        // 1. Validación client-side: evita el round-trip al servidor
        if item.inscriptosReales > 0 {
            self.errorMessage = "No se puede eliminar un curso con alumnos inscriptos. Eliminá las inscripciones primero."
            return
        }

        // 2. UI Optimista
        withAnimation {
            if let index = cursosProximos.firstIndex(where: { $0.id == item.id }) {
                cursosProximos.remove(at: index)
            }
            if let index = cursosHistoricos.firstIndex(where: { $0.id == item.id }) {
                cursosHistoricos.remove(at: index)
            }
        }

        // 3. Borrado real
        taskTracker.track(Task {
            do {
                try await tallerRepo.deleteCronogramaItem(item: item)
            } catch is CancellationError {
                // Tarea cancelada por ciclo de vida — no mostrar al usuario.
            } catch {
                // Rollback: re-suscribir restaura ambas listas desde el servidor
                self.subscribeToCronograma()
                self.errorMessage = FirestoreManager.mensajeAmigable(error)
            }
        })
    }
}
