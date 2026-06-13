#if DEBUG
import Foundation

/// Datos sintéticos para previews de SwiftUI (solo DEBUG).
/// Espeja el subset de `TestFactory` que necesitan las vistas, copiado al app
/// target (sin `@testable`). Mantener en sync con los modelos si cambian campos.
enum PreviewData {

    // Fecha base estable para todas las muestras.
    static let fechaBase = Date(timeIntervalSince1970: 1_750_000_000)
    static let proxima = Date().addingTimeInterval(60 * 60 * 24 * 3)   // +3 días
    static let pasada = Date().addingTimeInterval(-60 * 60 * 24 * 5)   // -5 días

    // MARK: Contactos

    static let contactos: [Contacto] = [
        Contacto(id: "c1", nombre: "María", apellido: "González", email: "maria@mail.com",
                 telefono: "1133224455", direccion: "Av. Siempre Viva 742",
                 redes_sociales: "@maria.glass", cuit: nil, notas: "Clienta frecuente"),
        Contacto(id: "c2", nombre: "Julián", apellido: "Pérez", email: nil,
                 telefono: "1144556677", direccion: nil, redes_sociales: nil,
                 cuit: nil, notas: nil),
        Contacto(id: "c3", nombre: "Sofía", apellido: "Ramírez", email: "sofi@mail.com",
                 telefono: nil, direccion: nil, redes_sociales: "@sofi.vitrofusion",
                 cuit: nil, notas: nil),
    ]

    // MARK: Cursos (catálogo + online)

    static let cursos: [Curso] = [
        Curso(id: "cur1", nombre: "Vitrofusión Inicial", tipo: .taller, precio: 18_000, cant_inscriptos: 4),
        Curso(id: "cur2", nombre: "Vitral Tiffany", tipo: .presencial, precio: 25_000, cant_inscriptos: 2),
    ]

    static let cursosOnline: [Curso] = [
        Curso(id: "on1", nombre: "Curso Online: Esmaltes", tipo: .online, precio: 12_000, cant_inscriptos: 8),
        Curso(id: "on2", nombre: "Curso Online: Murrinas", tipo: .online, precio: 9_500, cant_inscriptos: 5),
    ]

    // MARK: Cronograma

    static let cronogramaProximos: [CronogramaItem] = [
        CronogramaItem(id: "crono1", cursoId: "cur1", cursoNombre: "Vitrofusión Inicial",
                       cursoTipo: .taller, precio_curso: 18_000, fecha: proxima,
                       cant_inscriptos: 4, notas: "10:00 hs"),
        CronogramaItem(id: "crono2", cursoId: "cur2", cursoNombre: "Vitral Tiffany",
                       cursoTipo: .presencial, precio_curso: 25_000,
                       fecha: proxima.addingTimeInterval(60 * 60 * 24), cant_inscriptos: 2, notas: nil),
    ]

    static let cronogramaHistorico: [CronogramaItem] = [
        CronogramaItem(id: "crono3", cursoId: "cur1", cursoNombre: "Vitrofusión Inicial",
                       cursoTipo: .taller, precio_curso: 16_000, fecha: pasada,
                       cant_inscriptos: 6, notas: nil),
    ]

    // MARK: Inscripciones

    static let inscripciones: [Inscripcion] = [
        Inscripcion(id: "i1", alumnoId: "c1", alumno_nombre: "María González",
                    cronogramaId: "crono1", cursoId: "cur1", cursoNombre: "Vitrofusión Inicial",
                    cursoTipo: .taller, fecha_inscripcion: nil, fecha_curso: proxima,
                    precio_curso: 18_000, monto_abonado: 18_000, monto_adeudado: 0,
                    estado: .pagado, horario_inicio: "10:00", turnos: 1, notas: nil),
        Inscripcion(id: "i2", alumnoId: "c2", alumno_nombre: "Julián Pérez",
                    cronogramaId: "crono1", cursoId: "cur1", cursoNombre: "Vitrofusión Inicial",
                    cursoTipo: .taller, fecha_inscripcion: nil, fecha_curso: proxima,
                    precio_curso: 18_000, monto_abonado: 9_000, monto_adeudado: 9_000,
                    estado: .inscripto, horario_inicio: "10:00", turnos: 1, notas: nil),
    ]

    static let inscripcionesOnline: [Inscripcion] = [
        Inscripcion(id: "io1", alumnoId: "c3", alumno_nombre: "Sofía Ramírez",
                    cronogramaId: nil, cursoId: "on1", cursoNombre: "Curso Online: Esmaltes",
                    cursoTipo: .online, fecha_inscripcion: nil, fecha_curso: fechaBase,
                    precio_curso: 12_000, monto_abonado: 12_000, monto_adeudado: 0,
                    estado: .pagado, horario_inicio: nil, turnos: nil, notas: nil),
    ]

    // MARK: Pagos

    static let pagos: [Pago] = [
        Pago(id: "p1", fecha: fechaBase, monto: 18_000, medio_de_pago: .efectivo,
             cliente_id: "c1", cliente_nombre: "María González", tipo_venta: .taller,
             notas: nil, origen_tipo: .inscripcion, descripcion_origen: "Vitrofusión Inicial",
             origen_id: "i1"),
        Pago(id: "p2", fecha: fechaBase, monto: 25_000, medio_de_pago: .transferencia,
             cliente_id: "c2", cliente_nombre: "Julián Pérez", tipo_venta: .piezas,
             notas: nil, origen_tipo: .pedido, descripcion_origen: "#P-0002", origen_id: "ped2"),
        Pago(id: "p3", fecha: fechaBase, monto: 6_500, medio_de_pago: .mercadoPago,
             cliente_id: "c3", cliente_nombre: "Sofía Ramírez", tipo_venta: .materiales,
             notas: "Venta directa", origen_tipo: .ventaDirecta,
             descripcion_origen: "Materiales sueltos", origen_id: nil),
    ]

    // MARK: Pedidos

    static let pedidos: [Pedido] = [
        Pedido(id: "ped1", numero_pedido: "P-0001", cliente_id: "c1",
               cliente_nombre: "María González", presupuesto: 50_000, monto_abonado: 50_000,
               monto_adeudado: 0, estado_pago: true, fecha: fechaBase,
               descripcion: "Espejo decorado", tipo: .piezas, estado_entrega: true),
        Pedido(id: "ped2", numero_pedido: "P-0002", cliente_id: "c2",
               cliente_nombre: "Julián Pérez", presupuesto: 80_000, monto_abonado: 25_000,
               monto_adeudado: 55_000, estado_pago: false, fecha: fechaBase,
               descripcion: "Cuadro vitrofusión grande", tipo: .piezas, estado_entrega: false),
        Pedido(id: "ped3", numero_pedido: "P-0003", cliente_id: "c3",
               cliente_nombre: "Sofía Ramírez", presupuesto: 30_000, monto_abonado: 0,
               monto_adeudado: 30_000, estado_pago: false, fecha: fechaBase,
               descripcion: "Juego de portavasos", tipo: .materiales, estado_entrega: false),
    ]

    // MARK: Métricas

    static var metricas: MetricasFinancieras {
        var m = MetricasFinancieras()
        m.total_deuda_pedidos = 85_000
        m.total_deuda_inscripciones = 9_000
        return m
    }

    static let resumenDeuda: (real: Double, futuro: Double) = (55_000, 39_000)

    // MARK: Deudores

    static let deudores: [DeudorItem] = [
        DeudorItem(pedido: pedidos[1]),
        DeudorItem(pedido: pedidos[2]),
        DeudorItem(inscripcion: inscripciones[1]),
    ]
}
#endif
