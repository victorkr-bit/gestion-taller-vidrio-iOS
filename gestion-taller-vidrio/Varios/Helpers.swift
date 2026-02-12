import SwiftUI

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
