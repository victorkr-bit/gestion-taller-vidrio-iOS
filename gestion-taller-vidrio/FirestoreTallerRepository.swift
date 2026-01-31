import Foundation
import FirebaseFirestore // Solo esta importación, como indicaste.
import FirebaseFunctions


// Capa 4: Repositorio
// Unica clase concreta que funciona como Singleton [cite: 167]
final class FirestoreTallerRepository {
    
    // Formateador de fecha para enviar a Cloud Functions (ISO 8601)
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Instancia única (Singleton) para toda la app [cite: 47, 167]
    static let shared = FirestoreTallerRepository()
    
    // Referencia a la base de datos de Firestore 
    private let db = Firestore.firestore()
    
    // --- 2. AGREGAR ESTA PROPIEDAD ---
    // Instancia de Cloud Functions configurada para San Pablo (southamerica-east1).
    // Usamos 'lazy' para que se inicialice solo cuando se use por primera vez.
    private lazy var functions = Functions.functions(region: "southamerica-east1")
    
    // El inicializador es privado para asegurar que solo se pueda
    // acceder a través de la instancia .shared
    private init() {
        // En el futuro, aquí se podría configurar la caché, etc.
        // Por ahora, lo mantenemos simple.
    }
    
    // =============================================================
    // AQUÍ IRÁN LAS TAREAS 1.3 (Lecturas) y 1.4 (Escrituras)
    // =============================================================
    // --- INICIO CÓDIGO TAREA 1.3 ---
    // Este código debe ir DENTRO de la clase FirestoreTallerRepository

    // MARK: - Tarea 1.3: Lecturas (Fetch)

    /// Obtiene todos los contactos de la colección "contactos"
    func fetchContactos() async throws -> [Contacto] {
        // OPTIMIZACIÓN: Orden compuesto en el servidor.
        // Primero ordena por 'nombre', y si hay dos iguales, desempatar por 'apellido'.
        let snapshot = try await db.collection("contactos")
            .order(by: "nombre", descending: false)
            .order(by: "apellido", descending: false)
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            try? document.data(as: Contacto.self)
        }
    }
    /// Obtiene todos los cursos del catálogo "cursos"
    func fetchCursos() async throws -> [Curso] {
        let snapshot = try await db.collection("cursos").getDocuments()
        
        let cursos = snapshot.documents.compactMap { document in
            try? document.data(as: Curso.self)
        }
        
        return cursos
    }

    /// Obtiene todos los pedidos de la colección "pedidos"
    ///
    func fetchPedidos(limit: Int = 50) async throws -> [Pedido] {
        let snapshot = try await db.collection("pedidos")
            .order(by: "fecha", descending: true) // Los más nuevos primero
            .limit(to: limit) // Freno de mano para no fundir la tarjeta de crédito
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            try? document.data(as: Pedido.self)
        }
    }

    /// Obtiene los pagos dentro de un rango de fechas opcional [cite: 51]
 
    func fetchPagos(from: Date?, to: Date?) async throws -> [Pago] {
        var query: Query = db.collection("pagos")
        
        // Filtros
        if let fromDate = from {
            query = query.whereField("fecha", isGreaterThanOrEqualTo: fromDate)
        }
        if let toDate = to {
            query = query.whereField("fecha", isLessThanOrEqualTo: toDate)
        }
        
        // OPTIMIZACIÓN: Ordenamos en el servidor.
        // Nota: Si Firebase se queja, te dará un link en consola para crear el índice compuesto.
        query = query.order(by: "fecha", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Pago.self)
        }
        // Eliminamos el .sorted() final. El array ya viene ordenado.
    }

    

    /// Obtiene los cursos programados a futuro (incluyendo todo el día de hoy)
    func fetchCursosProximos() async throws -> [CronogramaItem] {
        // Usamos el inicio del día, no el segundo actual
        let hoyArgentina = getStartOfTodayInArgentina()
        
        let snapshot = try await db.collection("cronograma")
            .whereField("fecha", isGreaterThanOrEqualTo: hoyArgentina)
            .order(by: "fecha", descending: false)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: CronogramaItem.self) }
    }
    
    // MARK: - Fase 2: Métodos para Cursos Online (Evergreen)
        
    /// Obtiene exclusivamente el catálogo de cursos Online (sin fecha de agenda).
    /// Se usa para poblar la pestaña "Online" en la UI.
    func fetchCatalogoOnline() async throws -> [Curso] {
        let snapshot = try await db.collection("cursos")
            .whereField("tipo", isEqualTo: TipoCurso.online.rawValue)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: Curso.self) }
    }
    
    /// Escucha en tiempo real cambios en el catálogo Online.
    /// Esto permite que si 'cant_inscriptos' cambia por una venta, la UI se actualice sola.
    func listenToCatalogoOnline(completion: @escaping (Result<[Curso], Error>) -> Void) -> ListenerRegistration {
        
        let query = db.collection("cursos")
            .whereField("tipo", isEqualTo: TipoCurso.online.rawValue)
        
        // No ordenamos en la query para evitar índices complejos innecesarios ahora mismo,
        // ordenaremos en memoria en el ViewModel.
            
        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let cursos = documents.compactMap { try? $0.data(as: Curso.self) }
            completion(.success(cursos))
        }
    }

    /// Obtiene los cursos YA REALIZADOS (Pasado).
    /// Orden: Del más reciente hacia atrás (Descendente).
    /// Límite: Por defecto 20 (para ver lo último que pasó sin cargar el año entero).
    func fetchCursosHistoricos(limit: Int = 20) async throws -> [CronogramaItem] {
        
        // 1. Punto de corte: Hoy al inicio del día
        let hoy = Calendar.current.startOfDay(for: Date())
        
        // 2. Query Inversa
        let snapshot = try await db.collection("cronograma")
            .whereField("fecha", isLessThan: hoy)     // <--- Filtro: Solo lo que ya pasó
            .order(by: "fecha", descending: true)     // <--- IMPORTANTE: 'true' para ver primero el de "Ayer" y al final el de "2023"
            .limit(to: limit)                         // <--- El límite que pediste
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: CronogramaItem.self) }
    }

    /// Obtiene las inscripciones para un item de cronograma específico [cite: 51]
    func fetchInscripciones(cronogramaID: String) async throws -> [Inscripcion] {
        let snapshot = try await db.collection("inscripciones")
            .whereField("cronogramaId", isEqualTo: cronogramaID)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: Inscripcion.self) }
    }

    
    /// Obtiene los Pedidos e Inscripciones con deuda, ejecutando las consultas EN PARALELO.
    func fetchDeudores(limitPerCategory: Int = 50) async throws -> [DeudorItem] {
        
        // 1. Lanzamos la búsqueda de Pedidos en un hilo paralelo (background)
        // Usamos 'async let' para no bloquear la ejecución aquí.
        async let pedidosTask = db.collection("pedidos")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .order(by: "monto_adeudado", descending: true) // Traer primero a los que más deben
            .limit(to: limitPerCategory)
            .getDocuments()
        
        // 2. Lanzamos la búsqueda de Inscripciones en otro hilo paralelo
        async let inscripcionesTask = db.collection("inscripciones")
            .whereField("monto_adeudado", isGreaterThan: 0)
            .limit(to: limitPerCategory)
            .getDocuments()
        
        // 3. PUNTO DE SINCRONIZACIÓN (await)
        // Aquí esperamos a que AMBAS terminen. Si una falla, lanza error.
        let (pedidosSnapshot, inscripcionesSnapshot) = try await (pedidosTask, inscripcionesTask)
        
        // 4. Procesamiento en memoria (Rápido)
        
        // Mapear Pedidos
        let pedidosDeudores = pedidosSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let pedido = try? doc.data(as: Pedido.self) else { return nil }
            return DeudorItem(pedido: pedido)
        }
        
        // Mapear Inscripciones
        let inscripcionesDeudoras = inscripcionesSnapshot.documents.compactMap { doc -> DeudorItem? in
            guard let inscripcion = try? doc.data(as: Inscripcion.self) else { return nil }
            return DeudorItem(inscripcion: inscripcion)
        }
        
        // 5. Unificar y Ordenar Final
        // Como traemos datos de dos fuentes distintas, el ordenamiento final
        // inevitablemente debe hacerse en el cliente.
        let todos = pedidosDeudores + inscripcionesDeudoras
        
        return todos.sorted(by: { $0.fecha > $1.fecha }) // Los más recientes primero
    }
    // MARK: - Tarea A (Fase 3 Revisada): Lógica de Negocio y Borrado

    // Tarea A.2: Nueva función de lectura de pagos
    /// Obtiene los pagos asociados a un origen_id específico (Pedido o Inscripcion)
    func fetchPagos(origenID: String) async throws -> [Pago] {
        let snapshot = try await db.collection("pagos")
            .whereField("origen_id", isEqualTo: origenID)
            .getDocuments()
            
        let pagos = snapshot.documents.compactMap { document in
            try? document.data(as: Pago.self)
        }
        
        return pagos.sorted(by: { $0.fecha < $1.fecha }) // Los más antiguos primero
    }
    
    // --- INICIO CÓDIGO TAREA 1.4 ---
    // Este código debe ir DENTRO de la clase FirestoreTallerRepository
    
    // MARK: - Tarea 1.4: Escrituras Simples (CRUD) - CORRECCIÓN 2

   

    /// Borra un documento de Contacto
    func deleteContacto(contacto: Contacto) async throws {
        guard let id = contacto.id else {
            throw URLError(.cannotRemoveFile)
        }
        // (Esta función estaba bien, no da warnings)
        try await db.collection("contactos").document(id).delete()
    }

    /// Borra un documento de Curso
    /// Reemplaza a la antigua deleteCurso
    func deleteCurso(curso: Curso) async throws {
        guard let id = curso.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "cursos",
            "id": id
        ]
        
        do {
            // Llamada a la nube
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            // Si en el futuro agregamos reglas (ej: "No borrar curso si está en cronograma"),
            // el mapper manejará el error automáticamente.
            throw mapCloudError(error)
        }
    }
    
    // Tarea A.5: Modificar borrado de CronogramaItem
    // Reemplaza a la antigua deleteCronogramaItem
    func deleteCronogramaItem(item: CronogramaItem) async throws {
        guard let id = item.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "cronograma",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            // Si falla, el mapper lanzará TallerError.tieneInscriptos
            throw mapCloudError(error)
        }
    }
    
    // Tarea A.4: Nueva función de borrado de Inscripción
    // Reemplaza a la antigua deleteInscripcion
    func deleteInscripcion(inscripcion: Inscripcion) async throws {
        guard let id = inscripcion.id else { throw URLError(.cannotRemoveFile) }
        
        let data: [String: Any] = [
            "coleccion": "inscripciones",
            "id": id
        ]
        
        do {
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            throw mapCloudError(error)
        }
    }
    
    // Tarea A.3: Nueva función de borrado de Pedido
    // Reemplaza a la antigua deletePedido
    func deletePedido(pedido: Pedido) async throws {
        guard let id = pedido.id else { throw URLError(.cannotRemoveFile) }
        
        // Preparamos los datos para la Cloud Function 'borrarEntidad'
        let data: [String: Any] = [
            "coleccion": "pedidos",
            "id": id
        ]
        
        do {
            // Llamada a la nube
            _ = try await functions.httpsCallable("borrarEntidad").call(data)
        } catch {
            // Si falla (ej: tiene pagos), el mapper lanzará TallerError.tienePagos
            throw mapCloudError(error)
        }
    }
    
    // MARK: - Tarea 4.2 (Flujo 2): Borrar Pago
    
    /// Borra un pago y revierte atómicamente el saldo en el origen (si existe).
   func deletePago(pago: Pago) async throws {
       guard let id = pago.id else { throw TallerError.pagoNoEncontrado }
       
       let data: [String: Any] = [
           "pagoId": id
       ]
       
       do {
           _ = try await functions.httpsCallable("borrarPago").call(data)
       } catch {
           throw mapCloudError(error)
       }
   }

    /// Guarda (crea o actualiza) un documento de CronogramaItem
    func saveCronogramaItem(item: CronogramaItem) async throws {
        // 1. Codificamos manualmente
        let data = try Firestore.Encoder().encode(item)
        
        if let id = item.id {
            // 2. Usamos la versión (data:merge:)
            try await db.collection("cronograma").document(id).setData(data, merge: false)
        } else {
            // 3. Usamos la versión (data:)
            let _ = try await db.collection("cronograma").addDocument(data: data)
        }
    }
    
    /// Guarda un contacto.
    /// - Parameters:
    ///   - contacto: El objeto con los datos (se recomienda pasar id: nil aquí para evitar warnings).
    ///   - uid: El ID explícito donde queremos guardar el documento.
    func saveContacto(_ contacto: Contacto, uid: String) async throws {
        
        // 1. Codificamos el objeto (Firestore ignorará automáticamente la propiedad @DocumentID si es nil)
        let data = try Firestore.Encoder().encode(contacto)

        // 2. Guardamos usando el ID explícito en la ruta
        try await db.collection("contactos").document(uid).setData(data, merge: true)
    }
    
    /// Guarda (crea o actualiza) un documento de Curso
    func saveCurso(curso: Curso) async throws {
        // 1. Codificamos manualmente
        let data = try Firestore.Encoder().encode(curso)
        
        if let id = curso.id {
            // 2. Usamos la versión (data:merge:)
            try await db.collection("cursos").document(id).setData(data, merge: false)
        } else {
            // 3. Usamos la versión (data:)
            let _ = try await db.collection("cursos").addDocument(data: data)
        }
    }


    // MARK: - Tarea 3.1: Lógica de Pedidos (Híbrido)

    func savePedido(pedido: Pedido, existingID: String? = nil) async throws {
        
        // Usamos el ID explícito en lugar de confiar en pedido.id
        if let id = existingID {
            // A. EDICIÓN (Pasamos el ID explícito)
            try await updatePedidoRemote(pedido, id: id)
        } else {
            // B. CREACIÓN
            try await createPedidoRemote(pedido)
        }
    }

    private func createPedidoRemote(_ pedido: Pedido) async throws {
         // (Mismo código que tenías antes para crear, usando pedido.asCloudPayload)
         // ...
         let data = pedido.asCloudPayload // Asegúrate que esta propiedad exista según vimos antes
         _ = try await functions.httpsCallable("crearPedido").call(data)
    }

    private func updatePedidoRemote(_ pedido: Pedido, id: String) async throws {
        // Preparamos el payload usando la extensión nueva
        let payload: [String: Any] = [
            "id": id,
            "nuevosDatos": pedido.updatePayload
        ]
        
        do {
            // Llamamos a la nueva función TS 'actualizarPedido'
            _ = try await functions.httpsCallable("actualizarPedido").call(payload)
            
            // BENEFICIO:
            // Al terminar esto, el listener en tiempo real (listenToPedidos)
            // recibirá el documento actualizado con la deuda recalculada
            // y actualizará la UI automáticamente. Magia reactiva.
            
        } catch {
            throw mapCloudError(error)
        }
    }
    
    // MARK: - Tarea 3.2: Lógica de Cronograma

    // Tarea 3.2.1: saveInscripcion
    /// Guarda (crea o actualiza) un documento de Inscripcion.
    /// (Lógica simple, idéntica a saveContacto)
    func saveInscripcion(inscripcion: Inscripcion) async throws {
        // 1. Codificamos a Diccionario para poder manipular nulos
        let encoder = Firestore.Encoder()
        var data = try encoder.encode(inscripcion)
        
        // 2. CORRECCIÓN CRÍTICA PARA TRIGGER:
        // Si es Online (cronogramaId es nil), forzamos el envío de NSNull().
        // Si no hacemos esto, Firestore elimina la clave y la Cloud Function falla.
        if inscripcion.cronogramaId == nil {
            data["cronogramaId"] = NSNull()
        }
        
        // 3. Guardado
        if let id = inscripcion.id {
            // Actualizar
            try await db.collection("inscripciones").document(id).setData(data, merge: true)
        } else {
            // Crear
            let _ = try await db.collection("inscripciones").addDocument(data: data)
        }
    }
    
        
    // =============================================================
     // MARK: - FASE 4: NÚCLEO FINANCIERO
     // =============================================================

    // MARK: - Tarea 4.1: Registrar Pago (Vía Cloud Function)

    func registrarPago(pago: Pago, origen: Origen) async throws {
        
        // 1. Preparar payload básico
        var data: [String: Any] = [
            "monto": pago.monto,
            // CORRECCIÓN 1: Usamos .rawValue para el Enum MedioDePago
            "medio_de_pago": pago.medio_de_pago.rawValue,
            "notas": pago.notas ?? "",
            "fecha": isoDateFormatter.string(from: pago.fecha),
            "descripcion": pago.descripcion_origen,
            // OPTIMIZACIÓN LEAD DEV:
            // Mueve 'tipo_venta' aquí arriba.
            // El objeto 'pago' YA TIENE la verdad absoluta calculada por la UI.
            // No dependas de volver a calcularlo en el switch de abajo.
            "tipo_venta": pago.tipo_venta.rawValue
        ]
        
        // 2. Configurar el origen según el Enum
        switch origen {
        case .pedido(let pedido):
            guard let id = pedido.id else { throw TallerError.origenNoEncontrado }
            data["origenTipo"] = "pedido"
            data["origenId"] = id
            data["cliente_nombre"] = pedido.cliente_nombre
            data["cliente_id"] = pedido.cliente_id
            // CORRECCIÓN 2: El tipo del pedido también es Enum, usamos rawValue
            data["tipo_venta"] = pedido.tipo.rawValue
            
        case .inscripcion(let inscripcion):
            guard let id = inscripcion.id else { throw TallerError.origenNoEncontrado }
            data["origenTipo"] = "inscripcion"
            data["origenId"] = id
            data["cliente_nombre"] = inscripcion.alumno_nombre
            data["cliente_id"] = inscripcion.alumnoId
        }
        
        do {
            _ = try await functions.httpsCallable("registrarPago").call(data)
        } catch {
            throw mapCloudError(error)
        }
    }
     
    // MARK: - Tarea 4.3: Editar Pago (Vía Cloud Function)

    func editPago(pagoActualizado: Pago, montoAntiguo: Double) async throws {
        guard let pagoID = pagoActualizado.id else { throw TallerError.pagoNoEncontrado }
        
        let nuevosDatos: [String: Any] = [
            "monto": pagoActualizado.monto,
            "fecha": isoDateFormatter.string(from: pagoActualizado.fecha),
            // CORRECCIÓN 1: Enum .rawValue
            "medio_de_pago": pagoActualizado.medio_de_pago.rawValue,
            "notas": pagoActualizado.notas ?? "",
            "descripcion": pagoActualizado.descripcion_origen,
            // CORRECCIÓN 2: Enum .rawValue
            "tipo_venta": pagoActualizado.tipo_venta.rawValue
        ]
        
        let payload: [String: Any] = [
            "pagoId": pagoID,
            "nuevosDatos": nuevosDatos
        ]
        
        do {
            _ = try await functions.httpsCallable("editarPago").call(payload)
        } catch {
            throw mapCloudError(error)
        }
    }
     
     // MARK: - Tarea 4.4 (Flujo 4): Venta Directa
     
     /// Guarda un pago simple de Venta Directa (sin transacción).
    func saveVentaDirecta(pago: Pago) async throws {
        let data: [String: Any] = [
            "origenTipo": "Venta Directa",
            "origenId": NSNull(),
            "monto": pago.monto,
            // CORRECCIÓN 1: Enum .rawValue
            "medio_de_pago": pago.medio_de_pago.rawValue,
            "notas": pago.notas ?? "",
            "fecha": isoDateFormatter.string(from: pago.fecha),
            "cliente_nombre": pago.cliente_nombre,
            // CORRECCIÓN 2: Enum .rawValue
            "tipo_venta": pago.tipo_venta.rawValue
        ]
        
        do {
            _ = try await functions.httpsCallable("registrarPago").call(data)
        } catch {
            throw mapCloudError(error)
        }
    }
    
    // =============================================================
        // MARK: - FASE 5B: PANEL DE DEUDORES
        // =============================================================
        
        // --- TAREA: Flujo 6: Condonar Deuda ---
        
        /// Setea el monto_adeudado de un Pedido o Inscripción a 0 en una transacción.
        /// NO crea un registro en la colección 'pagos'.
        func condonarDeuda(origen: Origen) async throws {
            
            // 1. Obtenemos la referencia al documento de origen
            guard let origenRef = origen.ref else {
                throw TallerError.origenNoEncontrado
            }
            
            // 2. Ejecutar la transacción
            _ = try await db.runTransaction { (transaction, errorPointer) -> Void? in
                
                // 3. Definir los datos a actualizar
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
                
                // 4. Actualizar el documento de origen
                
                // --- INICIO DE LA CORRECCIÓN ---
                // Eliminamos el 'do-catch' innecesario.
                // Si 'updateData' falla, la transacción entera fallará
                // y el 'db.runTransaction' lanzará el error.
                transaction.updateData(dataParaActualizar, forDocument: origenRef)
                // --- FIN DE LA CORRECIÓN ---
                
                return nil
            }
        }
    
    // MARK: - Tarea 5: Lectura en Tiempo Real (Listener)
        
        /// Escucha cambios en la colección pagos dentro de un rango de fechas.
        /// Retorna un ListenerRegistration que debe ser guardado por el ViewModel para poder cancelar la escucha.
        func listenToPagos(from: Date?, to: Date?, completion: @escaping (Result<[Pago], Error>) -> Void) -> ListenerRegistration {
            
            // 1. Construimos la Query igual que antes
            var query: Query = db.collection("pagos")
            
            if let fromDate = from {
                query = query.whereField("fecha", isGreaterThanOrEqualTo: fromDate)
            }
            
            if let toDate = to {
                query = query.whereField("fecha", isLessThanOrEqualTo: toDate)
            }
            
            // 2. IMPORTANTE: Ordenamos por fecha descendente (más nuevos arriba) directamente en la base.
            // Nota: Esto puede requerir crear un índice compuesto en Firebase Console si usas filtros de rango + orden.
            // Si la consola te da error, te dará un link para crearlo con un clic.
            query = query.order(by: "fecha", descending: true)
            
            // 3. Activamos el Listener (.addSnapshotListener)
            let listener = query.addSnapshotListener { querySnapshot, error in
                
                // Manejo de errores
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Manejo de documentos vacíos
                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                // Decodificación
                let pagos = documents.compactMap { document in
                    try? document.data(as: Pago.self)
                }
                
                // Retornamos los datos "vivos"
                completion(.success(pagos))
            }
            
            return listener
        }
    
    
    // MARK: - Tarea 5.1: Listener de Inscripciones (Nuevo)

        /// Escucha en tiempo real las inscripciones de un cronograma específico
        func listenToInscripciones(cronogramaID: String, completion: @escaping (Result<[Inscripcion], Error>) -> Void) -> ListenerRegistration {
            
            // Usamos la corrección de nombre de campo que discutimos antes
            let query = db.collection("inscripciones")
                .whereField("cronogramaId", isEqualTo: cronogramaID)
            
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                // Decodificación segura: Si falla uno, no rompe a los demás
                var inscripciones: [Inscripcion] = []
                for doc in documents {
                    do {
                        let inscripcion = try doc.data(as: Inscripcion.self)
                        inscripciones.append(inscripcion)
                    } catch {
                        print("⚠️ Error decodificando inscripción \(doc.documentID): \(error)")
                        // Aquí podrías decidir si agregar una inscripción "parcial" o ignorarla
                    }
                }
                
                completion(.success(inscripciones))
            }
            
            return listener
        }
    
        /// Escucha en tiempo real las inscripciones HISTÓRICAS/GLOBALES de un curso Online.
        /// A diferencia de los talleres, aquí filtramos por 'cursoId' porque no hay fecha de cronograma.
    // Versión Final para listenToInscripcionesOnline
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
            
            // Mantenemos el bucle explícito para robustez
            for doc in documents {
                do {
                    let inscripcion = try doc.data(as: Inscripcion.self)
                    inscripciones.append(inscripcion)
                } catch {
                    // Solo imprimimos el error en modo Desarrollo
                    #if DEBUG
                    print("⚠️ Error decodificando inscripción (\(doc.documentID)): \(error)")
                    #endif
                    // En producción, simplemente ignoramos este documento corrupto y seguimos con el siguiente.
                }
            }
            
            completion(.success(inscripciones))
        }
    }
    
    // MARK: - Tarea 5.2: Listener de Pagos por Origen (Nuevo)
        
        /// Escucha en tiempo real los pagos de una inscripción o pedido específico
        func listenToPagos(origenID: String, completion: @escaping (Result<[Pago], Error>) -> Void) -> ListenerRegistration {
            
            let query = db.collection("pagos")
                .whereField("origen_id", isEqualTo: origenID)
            // No ordenamos en la query para evitar índices complejos si no existen,
            // ordenamos en memoria.
            
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let pagos = documents.compactMap { try? $0.data(as: Pago.self) }
                // Ordenar por fecha descendente
                let pagosOrdenados = pagos.sorted(by: { $0.fecha > $1.fecha })
                
                completion(.success(pagosOrdenados))
            }
            
            return listener
        }
    
    // MARK: - Tarea 5.3: Listener de Pedidos (Tiempo Real)
        
    /// Escucha cambios en tiempo real en la lista de pedidos.
    /// Esto permite que si una Cloud Function actualiza el saldo (deuda), la UI se refresque sola.
    func listenToPedidos(completion: @escaping (Result<[Pedido], Error>) -> Void) -> ListenerRegistration {
        
        // Ordenamos por fecha descendente (lo más nuevo arriba)
        let query = db.collection("pedidos")
            .order(by: "fecha", descending: true)
            
        let listener = query.addSnapshotListener { querySnapshot, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let pedidos = documents.compactMap { try? $0.data(as: Pedido.self) }
            completion(.success(pedidos))
        }
        
        return listener
    }
    
    // MARK: - Tarea 5.4: Listener de Cronograma (Requerimiento Lead Dev)
        
    /// Escucha en tiempo real los cursos PRÓXIMOS (desde hoy en adelante).
    /// Fundamental para actualizar el contador 'cant_inscriptos' sin recargar manualmente.
    func listenToCursosProximos(completion: @escaping (Result<[CronogramaItem], Error>) -> Void) -> ListenerRegistration {
        
        let hoyArgentina = getStartOfTodayInArgentina()
        
        let query = db.collection("cronograma")
            .whereField("fecha", isGreaterThanOrEqualTo: hoyArgentina)
            .order(by: "fecha", descending: false)
        
        let listener = query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let items = documents.compactMap { try? $0.data(as: CronogramaItem.self) }
            completion(.success(items))
        }
        
        return listener
    }
    
    // 1. Helper privado para obtener el "Hoy" de Argentina
        private func getStartOfTodayInArgentina() -> Date {
            var calendar = Calendar(identifier: .gregorian)
            // Forzamos la zona horaria de Argentina
            if let timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires") {
                calendar.timeZone = timeZone
            }
            // Devolvemos las 00:00:00 de hoy en hora Argentina
            return calendar.startOfDay(for: Date())
        }
    
    // MARK: - Helpers Privados (Cloud Functions)

        /// Traduce los errores genéricos de Firebase Functions a nuestros TallerError de dominio.
    private func mapCloudError(_ error: Error) -> TallerError {
        // 1. Casteamos a NSError para acceder al código y dominio
        let nsError = error as NSError
        
        // 2. Verificamos si es un error de Functions
        if nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code)
            let message = nsError.localizedDescription
            
            switch code {
            case .failedPrecondition:
                // Analizamos el mensaje de texto que enviamos desde TypeScript
                // Backend dice: "No se puede borrar: Tiene pagos asociados..."
                if message.lowercased().contains("pagos") {
                    return .tienePagos
                }
                // Backend dice: "No se puede borrar el curso: Tiene alumnos inscriptos."
                if message.lowercased().contains("inscriptos") || message.lowercased().contains("alumnos") {
                    return .tieneInscriptos
                }
                // Si es otra precondición desconocida
                return .transaccionFallida(message)
                
            case .notFound:
                return .origenNoEncontrado
                
            case .unauthenticated:
                return .transaccionFallida("Sesión no válida. Por favor, vuelve a iniciar sesión.")
                
            default:
                // Cualquier otro error (internal, cancelled, etc.)
                return .transaccionFallida(message)
            }
        }
        
        // 3. Si no es un error de Functions (ej. sin internet), lo pasamos tal cual o lo empaquetamos
        return .transaccionFallida(error.localizedDescription)
    }
    
    // MARK: - Métricas (Agregador)
        
    /// Obtiene los KPIs financieros pre-calculados por el servidor.
    /// Costo: 1 Lectura.
    func fetchMetricasFinancieras() async throws -> MetricasFinancieras {
        let doc = try await db.collection("metricas").document("finanzas").getDocument()
        
        // Si el documento no existe (base nueva), devolvemos métricas en 0
        guard doc.exists else {
            return MetricasFinancieras()
        }
        
        return try doc.data(as: MetricasFinancieras.self)
    }
    
    /// (Opcional) Escuchar cambios en tiempo real en las métricas
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

