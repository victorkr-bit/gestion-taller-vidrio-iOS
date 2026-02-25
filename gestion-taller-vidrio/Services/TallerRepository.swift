import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class TallerRepository {
    
    // Acceso a la infraestructura compartida
    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions
    
    // MARK: - Cursos (Catálogo Base)
    
    /// Obtiene todos los cursos del catálogo "cursos".
    func fetchCursos() async throws -> [Curso] {
        let snapshot = try await db.collection("cursos").getDocuments()

        return snapshot.documents.compactMap { document in
            document.decodeSafely(as: Curso.self)
        }
    }

    /// Escucha en tiempo real cambios en el catálogo completo de cursos.
    func listenToCursos(completion: @escaping (Result<[Curso], Error>) -> Void) -> ListenerRegistration {
        return db.collection("cursos").addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let cursos = documents.compactMap { $0.decodeSafely(as: Curso.self) }
            completion(.success(cursos))
        }
    }

    /// Guarda (crea o actualiza) un documento de Curso.
    func saveCurso(curso: Curso) async throws {
        // 1. Codificamos manualmente
        let data = try Firestore.Encoder().encode(curso)
        
        if let id = curso.id {
            // Actualización (merge: false para sobreescribir estructura si cambió)
            try await db.collection("cursos").document(id).setData(data, merge: false)
        } else {
            // Creación
            _ = try await db.collection("cursos").addDocument(data: data)
        }
    }
    
    /// Borra un curso validando dependencias vía Cloud Function.
    func deleteCurso(curso: Curso) async throws {
        guard let id = curso.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "cursos",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
    
    // MARK: - Cursos Online (Evergreen)
    
    /// Obtiene exclusivamente el catálogo de cursos Online (sin fecha de agenda).
    func fetchCatalogoOnline() async throws -> [Curso] {
        let snapshot = try await db.collection("cursos")
            .whereField("tipo", isEqualTo: TipoCurso.online.rawValue)
            .getDocuments()
            
        return snapshot.documents.compactMap { $0.decodeSafely(as: Curso.self) }
    }
    
    /// Escucha en tiempo real cambios en el catálogo Online.
    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("cursos")
            .whereField("tipo", isEqualTo: TipoCurso.online.rawValue)
        
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let cursos = documents.compactMap { $0.decodeSafely(as: Curso.self) }
            completion(.success(cursos))
        }
    }

    // MARK: - Cronograma (Agenda)

    /// Obtiene los cursos programados a futuro (incluyendo todo el día de hoy).
    func fetchCursosProximos() async throws -> [CronogramaItem] {
        let hoyArgentina = getStartOfTodayInArgentina()
        
        let snapshot = try await db.collection("cronograma")
            .whereField("fecha", isGreaterThanOrEqualTo: hoyArgentina)
            .order(by: "fecha", descending: false)
            .getDocuments()
            
        return snapshot.documents.compactMap { $0.decodeSafely(as: CronogramaItem.self) }
    }
    
    /// Escucha en tiempo real los cursos PRÓXIMOS.
    /// Fundamental para actualizar el contador 'cant_inscriptos' sin recargar manualmente.
    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> ListenerRegistration {
        let hoyArgentina = getStartOfTodayInArgentina()
        
        let query = db.collection("cronograma")
            .whereField("fecha", isGreaterThanOrEqualTo: hoyArgentina)
            .order(by: "fecha", descending: false)
        
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let items = documents.compactMap { $0.decodeSafely(as: CronogramaItem.self) }
            completion(.success(items))
        }
    }
    
    /// Obtiene los cursos YA REALIZADOS (Pasado).
    func fetchCursosHistoricos(limit: Int = 20) async throws -> [CronogramaItem] {
        let hoy = Calendar.current.startOfDay(for: Date())
        
        let snapshot = try await db.collection("cronograma")
            .whereField("fecha", isLessThan: hoy)
            .order(by: "fecha", descending: true)
            .limit(to: limit)
            .getDocuments()
            
        return snapshot.documents.compactMap { $0.decodeSafely(as: CronogramaItem.self) }
    }
    
    /// Guarda (crea o actualiza) un documento de CronogramaItem.
    func saveCronogramaItem(item: CronogramaItem) async throws {
        let data = try Firestore.Encoder().encode(item)
        
        if let id = item.id {
            try await db.collection("cronograma").document(id).setData(data, merge: false)
        } else {
            _ = try await db.collection("cronograma").addDocument(data: data)
        }
    }
    
    /// Actualiza precio, fecha y/o notas de un cronograma y propaga a inscripciones vía Cloud Function.
    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?) async throws {
        var nuevosDatos: [String: Any] = [:]
        if let precio = nuevoPrecio {
            nuevosDatos["precio"] = precio
        }
        if let fecha = nuevaFecha {
            nuevosDatos["fecha"] = Formatters.iso8601.string(from: fecha)
        }
        if let notas = nuevasNotas {
            nuevosDatos["notas"] = notas
        }

        let data: [String: Any] = [
            "id": id,
            "nuevosDatos": nuevosDatos
        ]

        do {
            _ = try await functions.httpsCallable("actualizarCronograma").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }

    /// Borra un ítem del cronograma validando inscripciones.
    func deleteCronogramaItem(item: CronogramaItem) async throws {
        guard let id = item.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "cronograma",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }

    // MARK: - Inscripciones
    
    /// Obtiene las inscripciones para un item de cronograma específico.
    func fetchInscripciones(cronogramaID: String) async throws -> [Inscripcion] {
        let snapshot = try await db.collection("inscripciones")
            .whereField("cronogramaId", isEqualTo: cronogramaID)
            .getDocuments()
            
        return snapshot.documents.compactMap { $0.decodeSafely(as: Inscripcion.self) }
    }
    
    /// Obtiene todos los contactos desde la colección 'contactos'.
    func fetchContactos() async throws -> [Contacto] {
        let snapshot = try await db.collection("contactos").getDocuments()
        return snapshot.documents.compactMap { $0.decodeSafely(as: Contacto.self) }
    }
    
    /// Escucha en tiempo real las inscripciones de un cronograma específico.
    func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("inscripciones")
            .whereField("cronogramaId", isEqualTo: cronogramaID)
        
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            var inscripciones: [Inscripcion] = []
            for doc in documents {
                if let inscripcion = doc.decodeSafely(as: Inscripcion.self) {
                    inscripciones.append(inscripcion)
                }
            }
            completion(.success(inscripciones))
        }
    }
    
    /// Escucha en tiempo real las inscripciones de un curso Online.
    func listenToInscripcionesOnline(cursoID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("inscripciones")
            .whereField("cursoId", isEqualTo: cursoID)
            .order(by: "fecha_curso", descending: true)
            
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            var inscripciones: [Inscripcion] = []
            for doc in documents {
                // Usamos try? para ser resilientes a datos corruptos en producción
                if let inscripcion = doc.decodeSafely(as: Inscripcion.self) {
                    inscripciones.append(inscripcion)
                }
            }
            completion(.success(inscripciones))
        }
    }
    
    /// Guarda (crea o actualiza) una inscripción.
    func saveInscripcion(inscripcion: Inscripcion) async throws {
        // 1. Codificamos a Diccionario para poder manipular nulos
        let encoder = Firestore.Encoder()
        var data = try encoder.encode(inscripcion)
        
        // 2. CRÍTICO: Si es Online, forzamos NSNull para cronogramaId
        if inscripcion.cronogramaId == nil {
            data["cronogramaId"] = NSNull()
        }
        
        // 3. Guardado
        if let id = inscripcion.id {
            try await db.collection("inscripciones").document(id).setData(data, merge: true)
        } else {
            _ = try await db.collection("inscripciones").addDocument(data: data)
        }
    }
    
    /// Borra una inscripción.
    func deleteInscripcion(inscripcion: Inscripcion) async throws {
        guard let id = inscripcion.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "inscripciones",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
    
    /// Obtiene inscripciones cuya `fecha_curso` cae dentro del rango dado.
    func fetchInscripcionesPorFecha(from: Date, to: Date) async throws -> [Inscripcion] {
        let snapshot = try await db.collection("inscripciones")
            .whereField("fecha_curso", isGreaterThanOrEqualTo: from)
            .whereField("fecha_curso", isLessThanOrEqualTo: to)
            .getDocuments()
        return snapshot.documents.compactMap { $0.decodeSafely(as: Inscripcion.self) }
    }

    // MARK: - Helpers Privados
    
    private func getStartOfTodayInArgentina() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        // Forzamos la zona horaria de Argentina
        if let timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires") {
            calendar.timeZone = timeZone
        }
        return calendar.startOfDay(for: Date())
    }
}
