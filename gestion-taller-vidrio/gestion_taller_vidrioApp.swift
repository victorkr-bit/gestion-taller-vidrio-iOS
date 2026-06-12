import SwiftUI
import FirebaseCore
import FirebaseAuth
import Combine

/// Detecta si el proceso corre dentro de un test runner (XCTest o Swift Testing).
/// En modo test la app actúa como host inerte: no configura Firebase ni abre listeners.
enum EntornoEjecucion {
    static let esTest: Bool =
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
}

// 1. Creamos un AppDelegate explícito para complacer a Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if !EntornoEjecucion.esTest {
            FirebaseApp.configure()
        }
        return true
    }
}

class AuthViewModel: ObservableObject {
    @Published var user: User?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        guard !EntornoEjecucion.esTest else { return }
        self.authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
        }
    }
    
    isolated deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            // signOut failures are extremely rare with Firebase
        }
    }
}

@main
struct TallerApp: App {
    // 2. Inyectamos el adaptador. Esto elimina el warning de "App Delegate does not conform..."
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if EntornoEjecucion.esTest {
                // Host inerte durante tests: no se crea AppContainer ni listeners de Firestore.
                Text("Modo test")
            } else if authViewModel.user != nil {
                MainView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
            }
        }
    }
}
