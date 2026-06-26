import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class TallerRepository: TallerRepositorio {
    
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
    func listenToCursos(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        let registration = db.collection("cursos").addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }

    /// Guarda (crea o actualiza) un documento de Curso.
    /// Al actualizar devuelve cuántos cronogramas e inscripciones fueron renombrados; al crear devuelve nil.
    func saveCurso(curso: Curso) async throws -> (cronogramas: Int, inscripciones: Int)? {
        if let id = curso.id {
            // Actualización: llamar CF para propagar cursoNombre a cronograma e inscripciones
            let payload: [String: Any] = [
                "id": id,
                "nuevosDatos": [
                    "nombre": curso.nombre,
                    "precio": curso.precio
                ]
            ]
            do {
                let result = try await functions.httpsCallable("actualizarCurso").call(payload)
                let data = result.data as? [String: Any] ?? [:]
                let cronogramas = data["cronogramasActualizados"] as? Int ?? 0
                let inscripciones = data["inscripcionesActualizadas"] as? Int ?? 0
                return (cronogramas: cronogramas, inscripciones: inscripciones)
            } catch {
                throw FirestoreManager.shared.mapCloudError(error)
            }
        } else {
            // Creación
            let data = try Firestore.Encoder().encode(curso)
            _ = try await db.collection("cursos").addDocument(data: data)
            return nil
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
    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> SuscripcionActiva {
        let query = db.collection("cursos")
            .whereField("tipo", isEqualTo: TipoCurso.online.rawValue)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
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
    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> SuscripcionActiva {
        let hoyArgentina = getStartOfTodayInArgentina()

        let query = db.collection("cronograma")
            .whereField("fecha", isGreaterThanOrEqualTo: hoyArgentina)
            .order(by: "fecha", descending: false)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }
    
    /// Obtiene los cursos YA REALIZADOS (Pasado).
    func fetchCursosHistoricos() async throws -> [CronogramaItem] {
        let hoy = Calendar.current.startOfDay(for: Date())

        let snapshot = try await db.collection("cronograma")
            .whereField("fecha", isLessThan: hoy)
            .order(by: "fecha", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { $0.decodeSafely(as: CronogramaItem.self) }
    }
    
    /// Obtiene un CronogramaItem por su document ID.
    func fetchCronogramaItem(id: String) async throws -> CronogramaItem? {
        let doc = try await db.collection("cronograma").document(id).getDocument()
        return try? doc.data(as: CronogramaItem.self)
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
    
    /// Actualiza precio, fecha, notas y/o cupo de un cronograma y propaga a inscripciones vía Cloud Function.
    /// `nuevoCupo`: nil = sin cambio; 0 = borrar (backend hace FieldValue.delete()); >0 = setear.
    func actualizarCronograma(id: String, nuevoPrecio: Double?, nuevaFecha: Date?, nuevasNotas: String?, nuevoCupo: Int?) async throws {
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
        if let cupo = nuevoCupo {
            nuevosDatos["cupo_maximo"] = cupo
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
    
    /// Escucha en tiempo real las inscripciones de un cronograma específico.
    func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        let query = db.collection("inscripciones")
            .whereField("cronogramaId", isEqualTo: cronogramaID)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }
    
    /// Escucha en tiempo real las inscripciones de un curso Online.
    func listenToInscripcionesOnline(cursoID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> SuscripcionActiva {
        let query = db.collection("inscripciones")
            .whereField("cursoId", isEqualTo: cursoID)
            .order(by: "fecha_curso", descending: true)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }
    
    /// Guarda (crea o actualiza) una inscripción. Retorna la inscripción con ID poblado.
    @discardableResult
    func saveInscripcion(inscripcion: Inscripcion) async throws -> Inscripcion {
        // 1. Codificamos a Diccionario para poder manipular nulos
        let encoder = Firestore.Encoder()
        var data = try encoder.encode(inscripcion)

        // 2. CRÍTICO: Si es Online, forzamos NSNull para cronogramaId
        if inscripcion.cronogramaId == nil {
            data["cronogramaId"] = NSNull()
        }

        // 3. Notas: escribir NSNull si está vacío para limpiar el campo en Firestore
        data["notas"] = inscripcion.notas.flatMap { $0.isEmpty ? nil : $0 } ?? NSNull()

        // 4. Guardado
        if let id = inscripcion.id {
            // Al editar, nunca pisar la fecha de inscripción original.
            data.removeValue(forKey: "fecha_inscripcion")
            try await db.collection("inscripciones").document(id).setData(data, merge: true)
            return inscripcion
        } else {
            // Al crear, sellar la fecha server-side (evita desfases de reloj del cliente).
            data["fecha_inscripcion"] = FieldValue.serverTimestamp()
            let ref = db.collection("inscripciones").document()
            try await ref.setData(data)
            var saved = inscripcion
            saved.id = ref.documentID
            return saved
        }
    }
    
    /// Mueve una inscripción a otro cronograma vía Cloud Function.
    func moverInscripcion(inscripcionId: String, destinoCronogramaId: String, adoptarPrecio: Bool) async throws {
        let data: [String: Any] = [
            "inscripcionId": inscripcionId,
            "destinoCronogramaId": destinoCronogramaId,
            "adoptarPrecio": adoptarPrecio
        ]
        do {
            _ = try await functions.httpsCallable("moverInscripcion").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
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
    
    /// Obtiene todas las inscripciones de un alumno específico.
    func fetchInscripcionesByAlumno(alumnoId: String) async throws -> [Inscripcion] {
        let snapshot = try await db.collection("inscripciones")
            .whereField("alumnoId", isEqualTo: alumnoId)
            .getDocuments()
        return snapshot.documents.compactMap { $0.decodeSafely(as: Inscripcion.self) }
    }

    /// Obtiene inscripciones cuya `fecha_curso` cae dentro del rango dado.
    func fetchInscripcionesPorFecha(from: Date, to: Date) async throws -> [Inscripcion] {
        let snapshot = try await db.collection("inscripciones")
            .whereField("fecha_curso", isGreaterThanOrEqualTo: from)
            .whereField("fecha_curso", isLessThanOrEqualTo: to)
            .getDocuments()
        return snapshot.documents.compactMap { $0.decodeSafely(as: Inscripcion.self) }
    }

    // MARK: - Preinscripciones (cursos presenciales)

    /// Escucha en tiempo real TODAS las preinscripciones de un cronograma.
    /// El filtrado por estado (pendiente) y el orden se hacen en el ViewModel para evitar índices compuestos.
    func listenToPreinscripciones(cronogramaID: String, completion: @escaping (Result<[Preinscripcion], Error>) -> Void) -> SuscripcionActiva {
        let query = db.collection("preinscripciones")
            .whereField("cronogramaId", isEqualTo: cronogramaID)

        let registration = query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }

            var preinscripciones: [Preinscripcion] = []
            for doc in documents {
                if let pre = doc.decodeSafely(as: Preinscripcion.self) {
                    preinscripciones.append(pre)
                }
            }
            completion(.success(preinscripciones))
        }
        return SuscripcionActiva { registration.remove() }
    }

    /// Confirma el pago de una preinscripción vía Cloud Function: crea/busca contacto, crea la
    /// inscripción firme, registra el pago y marca la preinscripción como convertida (transacción atómica).
    func confirmarPreinscripcion(preinscripcionId: String, monto: Double, medioDePago: MedioDePago) async throws {
        let data: [String: Any] = [
            "preinscripcionId": preinscripcionId,
            "monto": monto,
            "medio_de_pago": medioDePago.rawValue
        ]
        do {
            _ = try await functions.httpsCallable("confirmarPreinscripcion").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }

    /// Descarta una preinscripción (update directo, no requiere Cloud Function).
    func cancelarPreinscripcion(preinscripcionId: String) async throws {
        try await db.collection("preinscripciones").document(preinscripcionId)
            .updateData(["estado": EstadoPreinscripcion.cancelada.rawValue])
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
