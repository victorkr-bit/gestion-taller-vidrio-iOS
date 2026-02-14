import SwiftUI

// MARK: - Task Tracker (auto-limpieza de Tasks completados)

@MainActor
final class TaskTracker {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func track(_ task: Task<Void, Never>) {
        let id = UUID()
        tasks[id] = task
        Task {
            _ = await task.result
            self.tasks.removeValue(forKey: id)
        }
    }

    nonisolated func cancelAll() {
        MainActor.assumeIsolated {
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }
}

// MARK: - Error Alert Reutilizable
extension View {
    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        self.alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage.wrappedValue != nil },
            set: { if !$0 { errorMessage.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.wrappedValue ?? "Ocurrió un error desconocido.")
        }
    }
}
