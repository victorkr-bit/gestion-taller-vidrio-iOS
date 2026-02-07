# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Taller Cris" — iOS management app for a glass art workshop. Handles orders, payments, course scheduling, enrollments, contacts, and financial dashboards. All data lives in Firebase Firestore; there is no local persistence.

## Build & Run

- **Xcode project:** `gestion-taller-vidrio.xcodeproj` (no workspace needed)
- **Scheme:** `gestion-taller-vidrio`
- **Build from CLI:** `xcodebuild -project gestion-taller-vidrio.xcodeproj -scheme gestion-taller-vidrio -destination 'platform=iOS Simulator,name=iPhone 16' build`
- **Dependencies:** Swift Package Manager only (Firebase iOS SDK v12.6.0+: Auth, Core, Firestore, Functions). Packages resolve automatically on first build.
- **No tests exist.** No test targets are configured.

## Architecture

**MVVM + Repository pattern** with SwiftUI.

```
App Entry (gestion_taller_vidrioApp.swift)
  └─ AuthViewModel (Firebase Auth gate)
      ├─ LoginView
      └─ MainView (TabView, 5 tabs)
          ├─ Inicio → DashboardView / DashboardViewModel
          ├─ Cronograma → CronogramaView / CronogramaViewModel
          ├─ Pedidos → PedidosView / PedidosViewModel
          ├─ Caja → CajaView / CajaViewModel
          └─ Gestión → GestionView (contacts, courses admin)
```

### Dependency injection

Repositories are instantiated once in `MainView.init()` and injected into ViewModels via constructor. `DashboardViewModel` date filters are wired to `CajaViewModel` via Combine publishers (`$fechaInicio`, `$fechaFin`).

### Data layer

- **FirestoreManager** — singleton (`FirestoreManager.shared`) holding the `Firestore` and `Functions` instances. Also contains centralized Cloud Functions error mapping (`mapCloudError`).
- **Repositories** (3 `final class`es):
  - `FinanzasRepository` — payments (`pagos`), metrics (`metricas`)
  - `TallerRepository` — courses (`cursos`), schedule (`cronograma`), enrollments (`inscripciones`)
  - `VentasRepository` — orders (`pedidos`), contacts (`contactos`)
- Write operations go through **Firebase Cloud Functions** (region: `southamerica-east1`). Reads use Firestore listeners for real-time sync.

### Navigation

`NavigationManager` (environment object) controls tab selection (`AppTab` enum) and enables cross-tab navigation. Each tab wraps its content in a `NavigationStack`.

## Key Conventions

- **Language:** UI text, comments, variable names, and enum raw values are in **Spanish**.
- **All ViewModels** use `@MainActor` and conform to `ObservableObject`.
- **Error handling:** All domain errors map to `TallerError` enum (in `AppEnums.swift`), which provides `LocalizedError` descriptions in Spanish.
- **Enums** (`AppEnums.swift`): `TipoCurso`, `EstadoInscripcion`, `TipoPedido`, `TipoVenta`, `MedioDePago`, `OrigenTipoPago`. Raw values must match what Firestore stores — do not change them without updating the backend.
- **Formatters** (`Formatters.swift`): currency uses `es_AR` locale; dates use `es` locale with Argentina timezone.
- **Model payloads:** Models like `Pedido` and `Inscripcion` have `asCloudPayload` / `updatePayload` methods for constructing Cloud Function call dictionaries — keep these in sync with the backend contract.
- **Denormalized fields:** Client names are stored directly on orders/enrollments/payments (`cliente_nombre`, `alumno_nombre`) rather than joined at read time.

## Firestore Collections

`contactos`, `cursos`, `cronograma`, `pedidos`, `inscripciones`, `pagos`, `metricas` — each maps 1:1 to a model in `Modelos/`.

## Source Layout

```
gestion-taller-vidrio/
├── gestion_taller_vidrioApp.swift   # App entry, AppDelegate, AuthViewModel
├── MainView.swift                   # TabView root, DI wiring
├── Modelos/                         # Codable Firestore models
├── Services/                        # FirestoreManager + 3 repositories
├── ViewModels/                      # @MainActor ObservableObject VMs
├── Views/                           # SwiftUI views
└── Varios/                          # Enums, formatters, helpers, extensions
```
