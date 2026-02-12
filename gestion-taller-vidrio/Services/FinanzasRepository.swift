import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class FinanzasRepository {
    
    // Acceso a la infraestructura compartida
    private let db = FirestoreManager.shared.db
    private let functions = FirestoreManager.shared.functions
    

    // MARK: - Pagos (Lectura)
    
    /// Obtiene los pagos dentro de un rango de fechas.
    func fetchPagos(from: Date?, to: Date?) async throws -> [Pago] {
        var query: Query = db.collection("pagos")
        
        if let fromDate = from {
            query = query.whereField("fecha", isGreaterThanOrEqualTo: fromDate)
        }
        if let toDate = to {
            query = query.whereField("fecha", isLessThanOrEqualTo: toDate)
        }
        
        query = query.order(by: "fecha", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { $0.decodeSafely(as: Pago.self) }
    }

    /// Obtiene los pagos asociados a un origen_id específico (Pedido o Inscripcion).
    func fetchPagos(origenID: String) async throws -> [Pago] {
        let snapshot = try await db.collection("pagos")
            .whereField("origen_id", isEqualTo: origenID)
            .getDocuments()

        let pagos = snapshot.documents.compactMap { $0.decodeSafely(as: Pago.self) }
        
        return pagos.sorted(by: { $0.fecha > $1.fecha }) // Los más recientes primero
    }
    
    // MARK: - Pagos (Tiempo Real)
    
    /// Escucha cambios en la colección pagos dentro de un rango de fechas.
    func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> ListenerRegistration {
        var query: Query = db.collection("pagos")
        
        if let fromDate = from {
            query = query.whereField("fecha", isGreaterThanOrEqualTo: fromDate)
        }
        if let toDate = to {
            query = query.whereField("fecha", isLessThanOrEqualTo: toDate)
        }
        
        query = query.order(by: "fecha", descending: true)
        
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            let pagos = documents.compactMap { $0.decodeSafely(as: Pago.self) }
            completion(.success(pagos))
        }
    }

    /// Escucha en tiempo real los pagos de una inscripción o pedido específico (Acordeón).
    func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("pagos")
            .whereField("origen_id", isEqualTo: origenID)
            
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let pagos = documents.compactMap { $0.decodeSafely(as: Pago.self) }
            // Ordenar por fecha descendente en memoria
            let pagosOrdenados = pagos.sorted(by: { $0.fecha > $1.fecha })
            
            completion(.success(pagosOrdenados))
        }
    }
    
    // MARK: - Gestión de Pagos (Cloud Functions)
    
    /// Registra un pago y actualiza saldo del origen vía Cloud Function.
    func registrarPago(pago: Pago, origen: Origen) async throws {
        // 1. Preparar payload
        var data: [String: Any] = [
            "monto": pago.monto,
            "medio_de_pago": pago.medio_de_pago.rawValue,
            "notas": pago.notas ?? "",
            "fecha": Formatters.iso8601.string(from: pago.fecha),
            "descripcion": pago.descripcion_origen,
            "tipo_venta": pago.tipo_venta.rawValue
        ]
        
        // 2. Configurar origen
        switch origen {
        case .pedido(let pedido):
            guard let id = pedido.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
            data["origenTipo"] = "pedido"
            data["origenId"] = id
            data["cliente_nombre"] = pedido.cliente_nombre
            data["cliente_id"] = pedido.cliente_id
            
        case .inscripcion(let inscripcion):
            guard let id = inscripcion.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
            data["origenTipo"] = "inscripcion"
            data["origenId"] = id
            data["cliente_nombre"] = inscripcion.alumno_nombre
            data["cliente_id"] = inscripcion.alumnoId
        }
        
        do {
            _ = try await functions.httpsCallable("registrarPago").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
    
    /// Edita un pago existente y recalcula saldos vía Cloud Function.
    func editPago(pagoActualizado: Pago, montoAntiguo: Double) async throws {
        guard let pagoID = pagoActualizado.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
        
        let nuevosDatos: [String: Any] = [
            "monto": pagoActualizado.monto,
            "fecha": Formatters.iso8601.string(from: pagoActualizado.fecha),
            "medio_de_pago": pagoActualizado.medio_de_pago.rawValue,
            "notas": pagoActualizado.notas ?? "",
            "descripcion": pagoActualizado.descripcion_origen,
            "tipo_venta": pagoActualizado.tipo_venta.rawValue
        ]
        
        let payload: [String: Any] = [
            "pagoId": pagoID,
            "nuevosDatos": nuevosDatos
        ]
        
        do {
            _ = try await functions.httpsCallable("editarPago").call(payload)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
    
    /// Borra un pago y revierte atómicamente el saldo.
    func deletePago(pago: Pago) async throws {
        guard let id = pago.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
        
        let data: [String: Any] = [
            "pagoId": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarPago").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }
    
    /// Guarda un pago simple de Venta Directa (sin transacción de deuda).
    func saveVentaDirecta(pago: Pago) async throws {
        let data: [String: Any] = [
            "origenTipo": "Venta Directa",
            "origenId": NSNull(),
            "monto": pago.monto,
            "medio_de_pago": pago.medio_de_pago.rawValue,
            "notas": pago.notas ?? "",
            "fecha": Formatters.iso8601.string(from: pago.fecha),
            "cliente_nombre": pago.cliente_nombre,
            "tipo_venta": pago.tipo_venta.rawValue
        ]
        
        do {
            _ = try await functions.httpsCallable("registrarPago").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }

    // MARK: - Panel de Deudores
    
    /// Obtiene los Pedidos e Inscripciones con deuda en paralelo.
    func fetchDeudores(limitPerCategory: Int = 50) async throws -> [DeudorItem] {
        
        async let pedidosTask = db.collection("pedidos")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .order(by: "monto_adeudado", descending: true)
            .limit(to: limitPerCategory)
            .getDocuments()
        
        async let inscripcionesTask = db.collection("inscripciones")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .limit(to: limitPerCategory)
            .getDocuments()
        
        let (pedidosSnapshot, inscripcionesSnapshot) = try await (pedidosTask, inscripcionesTask)
        
        // Mapeo
        let pedidosDeudores = pedidosSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let pedido = doc.decodeSafely(as: Pedido.self) else { return nil }
            return DeudorItem(pedido: pedido)
        }

        let inscripcionesDeudoras = inscripcionesSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let inscripcion = doc.decodeSafely(as: Inscripcion.self) else { return nil }
            return DeudorItem(inscripcion: inscripcion)
        }
        
        let todos = pedidosDeudores + inscripcionesDeudoras
        return todos.sorted(by: { $0.fecha > $1.fecha })
    }
    
    /// Setea el monto_adeudado a 0 en una transacción (Condonar).
    func condonarDeuda(origen: Origen) async throws {
        guard let origenRef = origen.ref else {
            throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue))
        }
        
        _ = try await db.runTransaction { (transaction, errorPointer) -> Void? in
            
            let dataParaActualizar: [String: Any]
            
            switch origen {
            case .pedido:
                dataParaActualizar = [
                    "monto_adeudado": 0.0,
                    "estado_pago": true
                ]
            case .inscripcion:
                dataParaActualizar = [
                    "monto_adeudado": 0.0,
                    "estado": EstadoInscripcion.pagado.rawValue
                ]
            }
            
            transaction.updateData(dataParaActualizar, forDocument: origenRef)
            return nil
        }
    }
    
    // MARK: - Métricas (KPIs)
    
    /// Obtiene los KPIs financieros pre-calculados.
    func fetchMetricasFinancieras() async throws -> MetricasFinancieras {
        let doc = try await db.collection("metricas").document("finanzas").getDocument()
        guard doc.exists else { return MetricasFinancieras() }
        return try doc.data(as: MetricasFinancieras.self)
    }
    
    /// Escucha cambios en tiempo real en las métricas.
    func listenToMetricas(completion: @escaping (Result<MetricasFinancieras, Error>) -> Void) -> ListenerRegistration {
        return db.collection("metricas").document("finanzas")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(.success(MetricasFinancieras()))
                    return
                }
                
                do {
                    let metricas = try snapshot.data(as: MetricasFinancieras.self)
                    completion(.success(metricas))
                } catch {
                    completion(.failure(error))
                }
            }
    }
}
