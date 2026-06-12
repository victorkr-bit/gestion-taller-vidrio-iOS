import Foundation
@testable import gestion_taller_vidrio

/// Fábricas de modelos para tests. Solo datos sintéticos.
enum TestFactory {

    static func inscripcion(
        horario: String? = nil,
        turnos: Int? = nil,
        nombre: String = "Alumno Test"
    ) -> Inscripcion {
        Inscripcion(
            id: nil,
            alumnoId: "alumno-test-id",
            alumno_nombre: nombre,
            cronogramaId: "crono-test-id",
            cursoId: "curso-test-id",
            cursoNombre: "Curso Test",
            cursoTipo: .taller,
            fecha_inscripcion: nil,
            fecha_curso: Date(timeIntervalSince1970: 1_750_000_000),
            precio_curso: 10_000,
            monto_abonado: 0,
            monto_adeudado: 10_000,
            estado: .inscripto,
            horario_inicio: horario,
            turnos: turnos,
            notas: nil
        )
    }

    static func pedido(
        presupuesto: Double = 50_000,
        tipo: TipoPedido = .piezas,
        fecha: Date = Date(timeIntervalSince1970: 1_750_000_000)
    ) -> Pedido {
        Pedido(
            id: nil,
            numero_pedido: "P-0001",
            cliente_id: "cliente-test-id",
            cliente_nombre: "Cliente Test",
            presupuesto: presupuesto,
            monto_abonado: 0,
            monto_adeudado: presupuesto,
            estado_pago: false,
            fecha: fecha,
            descripcion: "Pedido de prueba",
            tipo: tipo,
            estado_entrega: false
        )
    }
}
