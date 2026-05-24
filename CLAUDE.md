# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Taller Cris" — iOS management app for a glass art workshop. Handles orders, payments, course scheduling, enrollments, contacts, leads, and financial dashboards. All data lives in Firebase Firestore; there is no local persistence.

## Workflow
- Before implementing any changes, explain your plan and list the files you'll modify.
- Wait for explicit approval before proceeding.
- Al proponer o mostrar ediciones de código, muéstralas siempre de forma expandida (sin truncar o resumir partes relevantes del bloque de código) para facilitar su revisión y aprobación.

## Build & Run

- **Xcode project:** `gestion-taller-vidrio.xcodeproj` (no workspace needed)
- **Scheme:** `gestion-taller-vidrio`
- **Simulator:** iPhone 17 Pro (always use this, no need to list available simulators)
- **Build from CLI:** `xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Dependencies:** Swift Package Manager only (Firebase iOS SDK v12.6.0+: Auth, Core, Firestore, Functions). Packages resolve automatically on first build.
- **No tests exist.** No test targets are configured.

## Architecture

**MVVM + Repository pattern** with SwiftUI.

```
App Entry (gestion_taller_vidrioApp.swift)
  └─ AuthViewModel (Firebase Auth gate)
      ├─ LoginView
      └─ MainView (TabView, 5 tabs)
          ├─ Inicio → DashboardView / MetricasVM + ChartsVM + ProximaActividadVM (+ FilterCoordinator)
          ├─ Agenda → AgendaView / AgendaVM + InscripcionesVM + CatalogoOnlineVM
          ├─ Pedidos → PedidosView / PedidosViewModel
          ├─ Pagos → PagosView / PagosViewModel
          └─ Gestión → GestionView (datos maestros, comercial, finanzas, sistema)
```

### Dependency injection — AppContainer

`AppContainer` (`Services/AppContainer.swift`) is a `@MainActor` singleton that instantiates all repositories and ViewModels once. `MainView` holds it as a `@StateObject`.

**Wiring sequence:**
1. Four repos created: `FinanzasRepository`, `TallerRepository`, `VentasRepository`, `ContactosRepository`
2. `FilterCoordinator` (mes inicio/fin compartido entre Dashboard / Actividad / Facturación)
3. `MetricasViewModel` gets `finanzasRepo` + `filterCoordinator` (KPIs + ingresos por tipo)
4. `ChartsViewModel` gets `finanzasRepo` + `tallerRepo` + `filterCoordinator` (facturación 12m, evolución clases, detalle período)
5. `ProximaActividadViewModel` gets `tallerRepo` (próximas clases + ocupación por hora)
6. `PagosViewModel` gets `finanzasRepo` + `contactosRepo`
7. `PedidosViewModel` gets `ventasRepo` + `finanzasRepo` + `contactosRepo` (factory de PedidoFormViewModel)
8. `InscripcionesViewModel` gets `tallerRepo` + `finanzasRepo` + `contactosRepo` (expone `contactosRepo` para `InscripcionFormView`)
9. `ContactoDetailViewModel` gets `tallerRepo`

VMs wired in AppContainer: `metricasVM`, `chartsVM`, `proximaActividadVM`, `pagosVM`, `agendaVM`, `inscripcionesVM`, `catalogoOnlineVM`, `pedidosVM`, `deudoresVM`, `contactoDetailVM`, `leadsVM`. `CursosViewModel`, `ContactosViewModel`, and `PedidoFormViewModel` are instantiated locally in their views. `FilterCoordinator` también vive en el container.

### Data layer

- **FirestoreManager** — singleton (`FirestoreManager.shared`) holding the `Firestore` and `Functions` instances. Contains centralized Cloud Functions error mapping (`mapCloudError`).
- **Repositories** (4 `final class`es):
  - `FinanzasRepository` — payments (`pagos`), metrics (`metricas`), debtors
  - `TallerRepository` — courses (`cursos`), schedule (`cronograma`), enrollments (`inscripciones`), leads (`leads`)
  - `VentasRepository` — orders (`pedidos`)
  - `ContactosRepository` — contacts (`contactos`) CRUD + cache en memoria. Única puerta a la colección `contactos`.
- **Write operations** go through Firebase Cloud Functions (region: `southamerica-east1`). Reads use Firestore listeners for real-time sync.

### Cloud Functions called

| Function name | Purpose |
|---|---|
| `crearPedido` | Create order |
| `actualizarPedido` | Update order (id + nuevosDatos) |
| `registrarPago` | Create payment + update origin balance |
| `editarPago` | Update payment + recalculate balance |
| `borrarPago` | Delete payment + revert balance |
| `borrarEntidad` | Generic delete with validation (checks pagos/inscriptos); also supports `leads` collection (no validation needed) |
| `actualizarCronograma` | Update schedule item + propagate to enrollments |
| `convertirLead` | Convert lead to contacto; returns `contactoId` |

### Real-time sync strategy

- **Listeners (real-time):** metrics, pagos (date-filtered), próximos cronograma, pedidos, inscripciones (per cronograma/curso), catálogo online, leads
- **One-shot fetches:** histórico cronograma, cursos catalog, contactos, deudores
- **On-demand listeners:** payment accordions per pedido/inscripción (lazy loaded, cleaned up on collapse)

### Navigation

`NavigationManager` (environment object) controls tab selection (`AppTab` enum: `inicio`, `cronograma`, `pedidos`, `pagos`, `gestion`) and cross-tab navigation. Each tab wraps its content in a `NavigationStack`. `cronogramaPath: NavigationPath` enables deep navigation from Dashboard → Cronograma detail. Most forms use `.sheet()` presentation.

## ViewModels (14 total)

All use `@MainActor` and conform to `ObservableObject`.

| ViewModel | Repo dependencies | Key responsibility | In AppContainer |
|---|---|---|---|
| `MetricasViewModel` | Finanzas, FilterCoordinator | KPIs (ingresos/deuda), pagos del período, ingresos por tipo, tendencia | Yes |
| `ChartsViewModel` | Finanzas, Taller, FilterCoordinator | Facturación 12m, evolución mensual de clases, detalle del período | Yes |
| `ProximaActividadViewModel` | Taller | Próximas clases (top 2) + ocupación por hora del taller | Yes |
| `PagosViewModel` | Finanzas, Contactos | Payment list, search, date filter | Yes |
| `PedidosViewModel` | Ventas, Finanzas, Contactos | Orders with dual filters (pago/entrega), payment accordions | Yes |
| `AgendaViewModel` | Taller | Schedule (próximos listener + histórico one-shot) | Yes |
| `InscripcionesViewModel` | Taller, Finanzas, Contactos | Enrollments (agenda & online), occupancy calculations | Yes |
| `CatalogoOnlineViewModel` | Taller | Online course catalog listener | Yes |
| `DeudoresViewModel` | Finanzas | Debtors panel, pay/forgive actions | Yes |
| `ContactoDetailViewModel` | Taller | Contact detail: enrollment history for a student | Yes |
| `CursosViewModel` | Taller | Course catalog CRUD | No (local) |
| `ContactosViewModel` | Contactos | Contacts with search filter | No (local) |
| `PedidoFormViewModel` | Ventas, Contactos | Order form (create/edit dual mode) | No (local) |
| `LeadsViewModel` | Taller | Leads list with real-time listener, filters, marcar notificado, convertir, borrar | Yes |

**`FilterCoordinator`** (`Services/FilterCoordinator.swift`) — `@MainActor ObservableObject` con `mesInicio`/`mesFin: MesAño` compartidos. `MetricasViewModel` y `ChartsViewModel` se suscriben vía Combine y reaccionan a cambios. `DashboardView`, `ActividadComercialView` y `FacturacionView` editan el filtro a través del mismo coordinador.

## Models (Modelos/)

| File | Firestore collection | Key fields |
|---|---|---|
| `Pedido.swift` | `pedidos` | numero_pedido, cliente_id/nombre, presupuesto, monto_abonado/adeudado, estado_pago, estado_entrega, tipo |
| `Inscripcion.swift` | `inscripciones` | alumnoId/nombre, cronogramaId?, cursoId?, precio_curso, monto_abonado/adeudado, estado, horario_inicio?, turnos?, fecha_inscripcion? (FechaFlexible), fecha_curso |
| `Pago.swift` | `pagos` | monto, medio_de_pago, cliente_id/nombre, tipo_venta, origen_tipo, origen_id?, descripcion_origen |
| `Curso.swift` | `cursos` | nombre, tipo (TipoCurso), precio, cant_inscriptos? |
| `CronogramaItem.swift` | `cronograma` | cursoId, cursoNombre, cursoTipo, precio_curso, fecha, cant_inscriptos? |
| `Contacto.swift` | `contactos` | nombre, apellido, email?, telefono?, direccion?, redes_sociales?, cuit?, notas? |
| `Metricas.swift` | `metricas/finanzas` | total_deuda_pedidos, total_deuda_inscripciones |
| `DeudorItem.swift` | (computed) | Union of Pedido/Inscripcion for debtors panel |
| `Lead.swift` | `leads` | nombre, canal, contacto, curso_interes, notas, estado (EstadoLead), fecha_ingreso (FechaFlexible)?, contacto_id? |

`Pedido` and `Inscripcion` have `asCloudPayload` / `updatePayload` methods — keep in sync with backend.

## Key Conventions

- **Language:** UI text, comments, variable names, and enum raw values are in **Spanish**.
- **Error handling:** Domain errors map to `TallerError` enum (in `AppEnums.swift`): `tienePagos`, `tieneInscriptos`, `origenNoEncontrado`, `pagoNoEncontrado`, `transaccionFallida(String)`. All provide `LocalizedError` descriptions in Spanish.
- **Enums** (`AppEnums.swift`): `TipoCurso`, `EstadoInscripcion`, `TipoPedido`, `TipoVenta`, `MedioDePago`, `OrigenTipoPago`. Raw values must match Firestore — do not change without updating backend. `TipoCurso`, `TipoVenta`, and `MedioDePago` have `.color` properties used in charts/badges.
- **Origen enum** (`Modelos/Origen.swift`): wraps `.pedido(Pedido)` / `.inscripcion(Inscripcion)` with computed properties for payment registration (clienteID, clienteNombre, tipoVenta, montoAdeudado, descripcionOrigen, Firestore ref).
- **Design system** (`Varios/DesignSystem.swift`): `DesignSystem` enum with `Radio`, `Sombra`, and `Espaciado` namespaces. Use these tokens instead of numeric literals. `sombraTarjeta()` View extension applies shadow presets.
- **Formatters** (`Formatters.swift`): currency `es_AR` locale (0 decimals); dates `es` locale with Argentina timezone; ISO8601 with fractional seconds for Cloud Functions.
- **Denormalized fields:** Client/student names stored directly on orders/enrollments/payments (`cliente_nombre`, `alumno_nombre`) — consistency maintained by Cloud Functions.
- **FechaFlexible** (`Modelos/Inscripcion.swift`): wrapper `Codable` usado por `Inscripcion.fecha_inscripcion`. Acepta Firestore Timestamp, String ISO8601, o ausencia sin lanzar error (evita descartar documentos por type mismatch). Nunca usar `init(from:)` manual en structs con `@DocumentID` — rompe la inyección del document ID y genera IDs `nil`.

## Source Layout

```
gestion-taller-vidrio/
├── gestion_taller_vidrioApp.swift   # App entry, AppDelegate, AuthViewModel
├── LoginView.swift                  # Firebase Auth login
├── MainView.swift                   # TabView root, holds AppContainer + NavigationManager
├── Modelos/
│   ├── Pedido.swift                 # Orders (with cloud payloads)
│   ├── Inscripcion.swift            # Enrollments (agenda + online)
│   ├── Pago.swift                   # Payments
│   ├── Curso.swift                  # Course catalog
│   ├── CronogramaItem.swift         # Scheduled events
│   ├── Contacto.swift               # Customers/students
│   ├── Metricas.swift               # Financial KPIs
│   ├── DeudorItem.swift             # Computed debtor (union type)
│   ├── DashboardModels.swift        # Structs compartidas: DetalleClases/Taller/Curso, OcupacionTallerItem, DatoGraficoTipo, DatoMensual, DatoMensualClases
│   ├── Origen.swift                 # Origen enum (.pedido/.inscripcion) for payment registration
│   └── Lead.swift                   # Lead + EstadoLead enum (pendiente/notificado/convertido)
├── Services/
│   ├── AppContainer.swift           # DI container (repos + coordinator + VMs)
│   ├── FirestoreManager.swift       # Firebase singleton + error mapping
│   ├── FilterCoordinator.swift      # Mes inicio/fin compartido (Dashboard/Actividad/Facturación)
│   ├── FinanzasRepository.swift     # Pagos, métricas, deudores
│   ├── TallerRepository.swift       # Cursos, cronograma, inscripciones
│   ├── VentasRepository.swift       # Pedidos
│   └── ContactosRepository.swift    # Contactos CRUD + cache
├── ViewModels/
│   ├── MetricasViewModel.swift       # KPIs (ingresos/deuda), pagos del período, ingresos por tipo, tendencia
│   ├── ChartsViewModel.swift         # Facturación 12m, evolución mensual de clases, detalle por período
│   ├── ProximaActividadViewModel.swift # Próximas clases (top 2) + ocupación por hora del taller
│   ├── PagosViewModel.swift          # Pagos with search + date filter
│   ├── PedidosViewModel.swift        # Orders + dual filters + payment accordions
│   ├── AgendaViewModel.swift         # Schedule (próximos/histórico)
│   ├── InscripcionesViewModel.swift  # Enrollments + occupancy
│   ├── CatalogoOnlineViewModel.swift # Online catalog listener
│   ├── DeudoresViewModel.swift       # Debtors panel
│   ├── ContactoDetailViewModel.swift # Enrollment history for a single contact
│   ├── CursosViewModel.swift         # Course CRUD (instantiated in view)
│   ├── ContactosViewModel.swift      # Contacts + search (instantiated in view)
│   ├── PedidoFormViewModel.swift     # Order form create/edit (instantiated in view)
│   └── LeadsViewModel.swift          # Leads: real-time listener, filtros, acciones (notificar/convertir/borrar)
├── Views/
│   ├── DashboardView.swift          # Inicio: próximas actividades + KPIs (ingresos/deuda) + filtro de período
│   ├── ActividadComercialView.swift # Gestión > Comercial > Actividad: evolución mensual + detalle por período
│   ├── FacturacionView.swift        # Gestión > Finanzas > Facturación: ingresos por tipo + facturación 13m
│   ├── AgendaView.swift             # Dual mode container (Agenda/Online)
│   ├── AgendaListView.swift         # Lista de cronograma (próximos/histórico)
│   ├── CalendarioAgendaView.swift   # Modal calendario 3 meses: días con cursos (accion) y feriados AR (alerta) via nager.date API
│   ├── OnlineListView.swift         # Lista de catálogo online
│   ├── AgendaDetailView.swift       # Schedule detail + enrollments
│   ├── AgendaFormView.swift         # Create schedule item
│   ├── EditarAgendaView.swift       # Edit schedule (precio/fecha)
│   ├── OnlineCourseDetailView.swift # Online course + enrollments
│   ├── InscripcionFormView.swift    # Enrollment form
│   ├── InscripcionRowView.swift     # Row de inscripción (reutilizable en detalles)
│   ├── MoverInscripcionView.swift   # Move enrollment to a different cronograma slot
│   ├── PedidosView.swift            # Orders list + filters
│   ├── PedidoFormView.swift         # Order form
│   ├── PagosView.swift              # Payment list with search + date filter
│   ├── PagosListView.swift          # Lista pura de pagos (sin filtros, reutilizable)
│   ├── PagoRowView.swift            # Reusable row for a single payment
│   ├── RegistrarPagoView.swift      # Payment registration
│   ├── PagoFormView.swift           # Payment edit
│   ├── VentaDirectaFormView.swift   # Direct sale
│   ├── DeudoresView.swift           # Debtors + swipe actions
│   ├── GestionView.swift            # Admin hub: Datos Maestros (contactos/cursos), Comercial (leads/actividad), Finanzas (deudores/facturación), Sistema (logout)
│   ├── ContactosView.swift          # Contacts list
│   ├── ContactoDetailView.swift     # Contact detail + enrollment history
│   ├── ContactoFormView.swift       # Create/edit contact form
│   ├── SelectorContactoView.swift   # Reusable contact picker sheet
│   ├── CursosView.swift             # Course catalog management
│   ├── CursoFormView.swift          # Create/edit course form
│   ├── LeadsView.swift              # Leads list + filtros + panel notificación + modal conversión
│   └── LeadRowView.swift            # Lead card: checkbox selección, datos, botón acción por estado, trash icon
└── Varios/
    ├── AppEnums.swift               # TipoCurso, EstadoInscripcion, TipoPedido, TipoVenta, MedioDePago, OrigenTipoPago, TallerError
    ├── Formatters.swift             # Currency (es_AR), dates (es/Argentina), ISO8601
    ├── NavigationManager.swift      # AppTab enum + cross-tab navigation
    ├── Helpers.swift                # MesAño/FiltroMesAñoView, TaskTracker, keyboard helpers, EstadoVacioView, BotonPrimario, errorAlert
    ├── DesignSystem.swift           # Design tokens: Radio, Sombra, Espaciado + sombraTarjeta() extension
    ├── Tallercalculator.swift       # Workshop occupancy calculations (per-hour, per-student overlap)
    ├── CardView.swift               # Reusable card styling component
    └── GenericRowView.swift         # Generic row with title, tags, date, amount
```

## Skills disponibles
- `swiftui-pro`: revisar vistas SwiftUI, API deprecada, performance
- `swift-concurrency-pro`: validar uso de async/await, actors, Swift 6

Cuando revises código Swift/SwiftUI, activar swiftui-pro y swift-concurrency-pro.


