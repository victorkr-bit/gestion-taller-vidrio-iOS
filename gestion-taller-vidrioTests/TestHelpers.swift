import Foundation
import FirebaseFirestore
@testable import gestion_taller_vidrio

/// Fábricas de modelos para tests. Solo datos sintéticos.
enum TestFactory {

    static func inscripcion(
        id: String? = nil,
        horario: String? = nil,
        turnos: Int? = nil,
        nombre: String = "Alumno Test",
        cursoNombre: String = "Curso Test",
        cursoTipo: TipoCurso = .taller,
        cronogramaId: String? = "crono-test-id",
        fechaCurso: Date = Date(timeIntervalSince1970: 1_750_000_000),
        montoAbonado: Double = 0,
        montoAdeudado: Double = 10_000
    ) -> Inscripcion {
        Inscripcion(
            id: id,
            alumnoId: "alumno-test-id",
            alumno_nombre: nombre,
            cronogramaId: cronogramaId,
            cursoId: "curso-test-id",
            cursoNombre: cursoNombre,
            cursoTipo: cursoTipo,
            fecha_inscripcion: nil,
            fecha_curso: fechaCurso,
            precio_curso: 10_000,
            monto_abonado: montoAbonado,
            monto_adeudado: montoAdeudado,
            estado: .inscripto,
            horario_inicio: horario,
            turnos: turnos,
            notas: nil
        )
    }

    static func pedido(
        id: String? = nil,
        presupuesto: Double = 50_000,
        tipo: TipoPedido = .piezas,
        fecha: Date = Date(timeIntervalSince1970: 1_750_000_000),
        numero: String = "P-0001",
        cliente: String = "Cliente Test",
        descripcion: String = "Pedido de prueba",
        montoAbonado: Double = 0,
        estadoPago: Bool = false,
        estadoEntrega: Bool = false
    ) -> Pedido {
        Pedido(
            id: id,
            numero_pedido: numero,
            cliente_id: "cliente-test-id",
            cliente_nombre: cliente,
            presupuesto: presupuesto,
            monto_abonado: montoAbonado,
            monto_adeudado: presupuesto - montoAbonado,
            estado_pago: estadoPago,
            fecha: fecha,
            descripcion: descripcion,
            tipo: tipo,
            estado_entrega: estadoEntrega
        )
    }

    static func pago(
        id: String? = "pago-test-id",
        monto: Double = 1_000,
        medio: MedioDePago = .efectivo,
        tipoVenta: TipoVenta = .taller,
        fecha: Date = Date(timeIntervalSince1970: 1_750_000_000),
        cliente: String = "Cliente Test",
        notas: String? = nil,
        descripcionOrigen: String = "Pago de prueba",
        origenID: String? = nil
    ) -> Pago {
        Pago(
            id: id,
            fecha: fecha,
            monto: monto,
            medio_de_pago: medio,
            cliente_id: "cliente-test-id",
            cliente_nombre: cliente,
            tipo_venta: tipoVenta,
            notas: notas,
            origen_tipo: origenID == nil ? .ventaDirecta : .pedido,
            descripcion_origen: descripcionOrigen,
            origen_id: origenID
        )
    }

    static func curso(
        id: String? = "curso-test-id",
        nombre: String = "Curso Test",
        tipo: TipoCurso = .presencial,
        precio: Double = 10_000
    ) -> Curso {
        Curso(
            id: id,
            nombre: nombre,
            tipo: tipo,
            precio: precio,
            cant_inscriptos: nil
        )
    }

    static func contacto(
        id: String? = "contacto-test-id",
        nombre: String = "Nombre",
        apellido: String = "Apellido"
    ) -> Contacto {
        Contacto(
            id: id,
            nombre: nombre,
            apellido: apellido,
            email: nil,
            telefono: nil,
            direccion: nil,
            redes_sociales: nil,
            cuit: nil,
            notas: nil
        )
    }

    static func cronogramaItem(
        id: String? = "crono-test-id",
        cursoNombre: String = "Curso Test",
        cursoTipo: TipoCurso = .taller,
        fecha: Date = Date(timeIntervalSince1970: 1_750_000_000),
        inscriptos: Int? = nil,
        cupo: Int? = nil
    ) -> CronogramaItem {
        CronogramaItem(
            id: id,
            cursoId: "curso-test-id",
            cursoNombre: cursoNombre,
            cursoTipo: cursoTipo,
            precio_curso: 10_000,
            fecha: fecha,
            cant_inscriptos: inscriptos,
            cupo_maximo: cupo,
            notas: nil
        )
    }

    static func preinscripcion(
        id: String? = "preins-test-id",
        nombre: String = "Nombre",
        apellido: String = "Apellido",
        cronogramaId: String = "crono-test-id",
        cursoNombre: String = "Curso Test",
        precioCurso: Double = 10_000,
        estado: EstadoPreinscripcion = .pendiente,
        email: String? = nil,
        telefono: String? = nil,
        notas: String? = nil,
        fechaCurso: Date = Date(timeIntervalSince1970: 1_750_000_000),
        fechaPreinscripcion: Date? = Date(timeIntervalSince1970: 1_749_000_000),
        esProfesorExterno: Bool? = nil
    ) -> Preinscripcion {
        Preinscripcion(
            id: id,
            cronogramaId: cronogramaId,
            cursoNombre: cursoNombre,
            cursoTipo: TipoCurso.presencial.rawValue,
            fecha_curso: Timestamp(date: fechaCurso),
            precio_curso: precioCurso,
            nombre: nombre,
            apellido: apellido,
            email: email,
            telefono: telefono,
            notas: notas,
            estado: estado,
            fecha_preinscripcion: fechaPreinscripcion.map { Timestamp(date: $0) },
            contacto_id: nil,
            inscripcion_id: nil,
            es_profesor_externo: esProfesorExterno
        )
    }
}

// MARK: - Espera de Tasks internos de los ViewModels

/// Espera (polling cooperativo) hasta que la condición sea true o se agote el timeout.
/// Los VMs lanzan Tasks internos no awaiteables; con fakes que responden al instante
/// alcanza con ceder el MainActor unas iteraciones.
@MainActor
func esperarCondicion(
    iteraciones: Int = 500,
    _ condicion: () -> Bool
) async -> Bool {
    for _ in 0..<iteraciones {
        if condicion() { return true }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
    return condicion()
}
