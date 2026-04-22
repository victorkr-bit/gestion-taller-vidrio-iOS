import Foundation

// Struct unificada (solo en la App) para el panel de Deudores
struct DeudorItem: Identifiable {
    let id: String
    let nombreCliente: String
    let montoAdeudado: Double
    let fecha: Date
    let descripcion: String
    let tipo: OrigenTipoPago // .pedido o .inscripcion
    
    // --- INICIO DE LA MODIFICACIÓN ---
    // Añadimos el objeto Origen.
    // Esto es VITAL para que los swipe actions (Pagar y Condonar)
    // sepan qué documento modificar.
    let origen: Origen
    // --- FIN DE LA MODIFICACIÓN ---
     
    // Inicializador para Pedido
    init(pedido: Pedido) {
        self.id = pedido.id ?? UUID().uuidString
        self.nombreCliente = pedido.cliente_nombre
        self.montoAdeudado = pedido.monto_adeudado
        self.fecha = pedido.fecha
        self.descripcion = "Pedido #\(pedido.numero_pedido)"
        self.tipo = .pedido
        
        // --- MODIFICACIÓN ---
        self.origen = .pedido(pedido)
    }
     
    // Inicializador para Inscripcion
    init(inscripcion: Inscripcion) {
        self.id = inscripcion.id ?? UUID().uuidString
        self.nombreCliente = inscripcion.alumno_nombre
        self.montoAdeudado = inscripcion.monto_adeudado
        self.fecha = inscripcion.fecha_inscripcion?.value ?? inscripcion.fecha_curso
        self.descripcion = "Inscripción: \(inscripcion.cursoNombre)"
        self.tipo = .inscripcion
        
        // --- MODIFICACIÓN ---
        self.origen = .inscripcion(inscripcion)
    }
}
