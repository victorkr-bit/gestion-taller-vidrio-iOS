import SwiftUI
import FirebaseAuth // Necesario para Auth.auth()

/**
 * Vista de Login simple (Tarea 0.5)
 *
 */
struct LoginView: View {
    
    // Estado para los campos de texto
    @State private var email = ""
    @State private var password = ""
    
    // Estado para manejar la carga y los errores
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
            Color(.systemBackground).ignoresSafeArea()
                .onTapGesture { hideKeyboard() }
            VStack(spacing: 20) {
                
                Spacer()
                
                // Título de la App
                Image(systemName: "hammer") // Icono temporal
                    .font(.system(size: 60))
                Text("Gestión de Taller")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Campos de formulario
                
                VStack {
                    TextField("Email", text: $email)
                        // 1. Aplicar estos modificadores PRIMERO
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        // 2. Aplicar los modificadores de estilo DESPUÉS
                        .padding()
                        .background(Color(.secondarySystemBackground)) // <-- Fix for SwiftUI
                        .cornerRadius(10)


                    SecureField("Contraseña", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground)) // <-- Fix for SwiftUI
                        .cornerRadius(10)
                }
                
                // Botón de Login
                BotonPrimario(titulo: "Ingresar", accion: loginUser, estaCargando: isLoading)
                
                // Mensaje de Error
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                Spacer()
                
            }
            .padding(.horizontal)
            } // ZStack
        }
    }
    
    /**
     * Lógica para autenticar al usuario con Firebase
     */
    func loginUser() {
        // Reiniciar estado
        isLoading = true
        errorMessage = ""
        
        // (Asumimos que el usuario admin ya fue creado en la consola Tarea 0.3)
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            isLoading = false
            
            if let error = error {
                // Si hay un error, lo mostramos
                errorMessage = "Error: \(error.localizedDescription)"
            }
            
            // Si el login es exitoso, el 'listener' en la vista principal
            // (que crearemos a continuación) detectará el cambio
            // y mostrará la MainView automáticamente.
        }
    }
}

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
