# Gestion Taller Vidrio — iOS App

An iOS management application built natively with **SwiftUI** and **Firebase**, designed to handle the complete workflow of a professional glass art workshop ("Taller Cris"). The app manages course scheduling, student enrollments, custom orders, real-time customer balances, and financial metrics.

## 🚀 Core Features

*   **Comprehensive Dashboards:** Real-time financial KPIs (revenue vs. debt), revenue distribution graphs by type, monthly business activity evolution, and upcoming workshop occupation heatmaps.
*   **Course & Agenda Management:** Dual-mode scheduling covering in-person classes (with calendar-based holiday integration for Argentina) and online asynchronous courses.
*   **Order & Payment Tracking:** Lifecycle management of custom glass work orders, from initial budget to delivery status, integrated with real-time payment settlement tracking.
*   **Smart Automated Balances:** Centralized debtors panel with sliding shortcuts to register payments or forgive balances.
*   **Real-Time Infrastructure:** Event-driven architecture utilizing direct Firestore listeners for responsive reads and Firebase Cloud Functions to process strict atomic write actions.

---

## 🛠️ Architecture & Tech Stack

The project follows a modular **MVVM + Repository Pattern** strictly bound to the `@MainActor` state to enforce thread-safe UI rendering.

### Technical Specs:
*   **UI Framework:** SwiftUI (Structured around single-purpose views and reusable design tokens).
*   **Asynchrony:** Modern Swift Concurrency (`async/await`, custom actors for cache isolation).
*   **Dependency Injection:** Centralized via an `AppContainer` lifecycle singleton.
*   **Database & Auth:** Firebase Firestore (Real-time syncing) + Firebase Auth.
*   **Business Logic Backend:** Isolated Firebase Cloud Functions (Region: `southamerica-east1`) ensuring data denormalization consistency.
*   **Local Formatting:** Hardened local presets (`es_AR` currency rules, Spanish date formatters, and custom time-zone handlers).

---

## 📦 Project Structure

```text
gestion-taller-vidrio/
├── gestion_taller_vidrioApp.swift   # App lifecycle entry point & Auth gate
├── MainView.swift                   # Main routing hub and TabView definitions
├── Modelos/                         # Decodable domain entities (Pedido, Pago, Inscripcion, etc.)
├── Services/                        # AppContainer, Firestore Managers, and Core Repositories
├── ViewModels/                      # UI-state managers mapping business rules to SwiftUI bindings
├── Views/                           # Decoupled interface components and modular screens
└── Varios/                          # Design System tokens, native Formatters, and layout helpers
```

---

## ⚙️ Build & Setup Instructions

### Prerequisites
*   Mac computer running macOS Sequoia (or higher).
*   **Xcode 15+** with Swift 5.10 / Swift 6 toolchains.
*   A Firebase project configuration instance.

### Step-by-Step Configuration

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/your-username/gestion-taller-vidrio-iOS.git
   cd gestion-taller-vidrio-iOS
   ```

2. **Add Infrastructure Credentials:**
   The repository does not bundle production database settings. You need to provision your own project descriptor file:
   * Locate `gestion-taller-vidrio/GoogleService-Info.plist.example`.
   * Duplicate the file and rename the copy to `GoogleService-Info.plist`.
   * Open it and fill the fields (`API_KEY`, `PROJECT_ID`, etc.) with your actual Firebase Client tokens.

3. **Open and Compile:**
   Open `gestion-taller-vidrio.xcodeproj` directly in Xcode.
   * **Dependencies:** Managed natively via **Swift Package Manager**. Dependencies (Firebase iOS SDK) will automatically fetch and resolve upon the initial build.
   * Select your target simulator (e.g., iPhone 17 Pro) and press `Cmd + R`.

### Automated Versioning
The project includes a pre-compile automated build phase script (`build-version.sh`). Every compilation reads Git metadata to dynamically stamp Calendar Versioning variables combined with short Git Hashes into `Version.swift` (`vYY.MM.DD (GitHash)`), displaying the deployment version straight inside the app's system panel footer.

---

## ✒️ Development Conventions

*   **Language:** While the repository structure and technical setups are configured in English, all domain models, structural database names, variables, interface strings, and in-code comments are written in **Spanish** to align directly with local operations.
*   **Strict Writes:** Writes never execute directly from the client application. Mutating documents (such as editing payments or processing enrollment slots) strictly invoke dedicated serverless Cloud Functions to ensure balance recalculations stay intact.
