
// Agrega esto en DashboardViewModel.swift o en un archivo Models.swift

struct IngresoUIModel: Identifiable {
    let id: TipoVenta // Para Identifiable
    let tipo: String  // Nombre ya capitalizado (ej: "Taller")
    let rawMonto: Double // Necesario para el alto de la barra del gráfico
    let montoFormateado: String // Pre-calculado: "$ 150.000"
    let porcentajeFormateado: String // Pre-calculado: "(15.0%)"
    let color: TipoVenta // Pasamos el enum para que la vista decida el color (o inyectamos Color si rompemos un poco MVVM, pero mantengamos el enum por pureza)
}
