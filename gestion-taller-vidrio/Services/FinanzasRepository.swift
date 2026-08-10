import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class FinanzasRepository: FinanzasRepositorio {
    
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
    func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        var query: Query = db.collection("pagos")

        if let fromDate = from {
            query = query.whereField("fecha", isGreaterThanOrEqualTo: fromDate)
        }
        if let toDate = to {
            query = query.whereField("fecha", isLessThanOrEqualTo: toDate)
        }

        query = query.order(by: "fecha", descending: true)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }

    /// Escucha en tiempo real los pagos de una inscripción o pedido específico (Acordeón).
    func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> SuscripcionActiva {
        let query = db.collection("pagos")
            .whereField("origen_id", isEqualTo: origenID)

        let registration = query.addSnapshotListener { querySnapshot, error in
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
        return SuscripcionActiva { registration.remove() }
    }
    
    // MARK: - Gestión de Pagos (Cloud Functions)
    
    /// Registra un pago y actualiza saldo del origen vía Cloud Function.
    /// `pagosSplit` (cursos de profesor externo): 1-2 entradas (adelanto/pago), cada una
    /// con su propio medio de pago — reemplaza monto/medio_de_pago en el payload.
    func registrarPago(pago: Pago, origen: Origen, pagosSplit: [PagoSplitEntry]?) async throws {
        // 1. Configurar origen
        let origenTipo: String
        let origenId: String
        let clienteNombre: String
        let clienteId: String
        switch origen {
        case .pedido(let pedido):
            guard let id = pedido.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
            origenTipo = "pedido"
            origenId = id
            clienteNombre = pedido.cliente_nombre
            clienteId = pedido.cliente_id

        case .inscripcion(let inscripcion):
            guard let id = inscripcion.id else { throw FirestoreManager.shared.mapCloudError(NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.notFound.rawValue)) }
            origenTipo = "inscripcion"
            origenId = id
            clienteNombre = inscripcion.alumno_nombre
            clienteId = inscripcion.alumnoId
        }

        // 2. Extraer campos de `pago` a valores simples
        let pagoNotas = pago.notas ?? ""
        let pagoFecha = Formatters.iso8601.string(from: pago.fecha)
        let pagoDescripcion = pago.descripcion_origen
        let pagoTipoVenta = pago.tipo_venta.rawValue
        let pagoMonto = pago.monto
        let pagoMedio = pago.medio_de_pago.rawValue

        // 3. Armar el array de pagos_split con un for-loop (sin closures: .map con literales
        //    anidados dispara "sending non-Sendable [String: Any]" en Swift 6 al cruzar el await).
        var pagosSplitPayload: [[String: Any]] = []
        if let pagosSplit {
            for entry in pagosSplit {
                pagosSplitPayload.append([
                    "monto": entry.monto,
                    "medio_de_pago": entry.medioDePago.rawValue,
                    "categoria_reparto": entry.categoriaReparto.rawValue
                ])
            }
        }

        var data: [String: Any] = [
            "notas": pagoNotas,
            "fecha": pagoFecha,
            "descripcion": pagoDescripcion,
            "tipo_venta": pagoTipoVenta,
            "origenTipo": origenTipo,
            "origenId": origenId,
            "cliente_nombre": clienteNombre,
            "cliente_id": clienteId
        ]
        if !pagosSplitPayload.isEmpty {
            data["pagos_split"] = pagosSplitPayload
        } else {
            data["monto"] = pagoMonto
            data["medio_de_pago"] = pagoMedio
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
            "fecha": Formatters.dateOnly(pagoActualizado.fecha),
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
            "cliente_nombre": pago.cliente_nombre,
            "cliente_id": pago.cliente_id,
            "tipo_venta": pago.tipo_venta.rawValue,
            "descripcion": pago.descripcion_origen
        ]

        do {
            _ = try await functions.httpsCallable("registrarPago").call(data)
        } catch {
            throw FirestoreManager.shared.mapCloudError(error)
        }
    }

    // MARK: - Resumen de deuda (Dashboard)

    /// Separa la deuda real (cobros vencidos) del monto a cobrar futuro.
    /// Usa una sola desigualdad por colección (índice automático) y particiona en cliente.
    func fetchResumenDeuda() async throws -> (real: Double, futuro: Double) {
        let ahora = Date()

        async let pedidosTask = db.collection("pedidos")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .getDocuments()

        async let inscripcionesTask = db.collection("inscripciones")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .getDocuments()

        let (pedidosSnapshot, inscripcionesSnapshot) = try await (pedidosTask, inscripcionesTask)

        var real: Double = 0
        var futuro: Double = 0

        for doc in pedidosSnapshot.documents {
            guard let pedido = doc.decodeSafely(as: Pedido.self) else { continue }
            // Pedido entregado con deuda = vencido (real); no entregado = a cobrar (futuro)
            if pedido.estado_entrega { real += pedido.monto_adeudado }
            else { futuro += pedido.monto_adeudado }
        }

        for doc in inscripcionesSnapshot.documents {
            guard let inscripcion = doc.decodeSafely(as: Inscripcion.self) else { continue }
            // Curso ya realizado con deuda = vencido (real); futuro = a cobrar
            if inscripcion.fecha_curso < ahora { real += inscripcion.monto_adeudado }
            else { futuro += inscripcion.monto_adeudado }
        }

        return (real: real, futuro: futuro)
    }

    // MARK: - Panel de Deudores

    /// Obtiene los Pedidos entregados e Inscripciones a cursos ya realizados con deuda pendiente.
    /// Filtra en cliente (estado_entrega / fecha_curso) para evitar índices compuestos.
    func fetchDeudores() async throws -> [DeudorItem] {
        let ahora = Date()

        async let pedidosTask = db.collection("pedidos")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .getDocuments()

        async let inscripcionesTask = db.collection("inscripciones")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .getDocuments()

        let (pedidosSnapshot, inscripcionesSnapshot) = try await (pedidosTask, inscripcionesTask)

        let pedidosDeudores = pedidosSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let pedido = doc.decodeSafely(as: Pedido.self), pedido.estado_entrega else { return nil }
            return DeudorItem(pedido: pedido)
        }

        let inscripcionesDeudoras = inscripcionesSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let inscripcion = doc.decodeSafely(as: Inscripcion.self), inscripcion.fecha_curso < ahora else { return nil }
            return DeudorItem(inscripcion: inscripcion)
        }

        let todos = pedidosDeudores + inscripcionesDeudoras
        return todos.sorted(by: { $0.fecha > $1.fecha })
    }

    // MARK: - Métricas (KPIs)
    
    /// Obtiene los KPIs financieros pre-calculados.
    func fetchMetricasFinancieras() async throws -> MetricasFinancieras {
        let doc = try await db.collection("metricas").document("finanzas").getDocument()
        guard doc.exists else { return MetricasFinancieras() }
        return try doc.data(as: MetricasFinancieras.self)
    }
    
    /// Escucha cambios en tiempo real en las métricas.
    func listenToMetricas(completion: @escaping (Result<MetricasFinancieras, Error>) -> Void) -> SuscripcionActiva {
        let registration = db.collection("metricas").document("finanzas")
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
        return SuscripcionActiva { registration.remove() }
    }
}
