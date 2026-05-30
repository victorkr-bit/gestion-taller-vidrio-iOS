import Foundation

// Struct unificada (solo en la App) para el panel de Deudores
struct DeudorItem: Identifiable {
    let id: String
    let nombreCliente: String
    let montoAdeudado: Double
    let fecha: Date
    let descripcion: String
    let tipo: OrigenTipoPago // .pedido o .inscripcion
    let estaVencida: Bool
    let origen: Origen

    // Inicializador para Pedido
    init(pedido: Pedido) {
        self.id = pedido.id ?? UUID().uuidString
        self.nombreCliente = pedido.cliente_nombre
        self.montoAdeudado = pedido.monto_adeudado
        self.fecha = pedido.fecha
        self.descripcion = "#\(pedido.numero_pedido)"
        self.tipo = .pedido
        self.estaVencida = false
        self.origen = .pedido(pedido)
    }

    // Inicializador para Inscripcion
    init(inscripcion: Inscripcion) {
        self.id = inscripcion.id ?? UUID().uuidString
        self.nombreCliente = inscripcion.alumno_nombre
        self.montoAdeudado = inscripcion.monto_adeudado
        self.fecha = inscripcion.fecha_inscripcion?.value ?? inscripcion.fecha_curso
        let cal = Calendar.current
        let day = cal.component(.day, from: inscripcion.fecha_curso)
        let month = cal.component(.month, from: inscripcion.fecha_curso)
        self.descripcion = String(format: "%@ (%02d/%02d)", inscripcion.cursoNombre, day, month)
        self.tipo = .inscripcion
        self.estaVencida = inscripcion.fecha_curso < Date()
        self.origen = .inscripcion(inscripcion)
    }
}
