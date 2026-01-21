import SwiftUI
import FirebaseCore
import FirebaseAuth
import Combine

// 1. Creamos un AppDelegate explícito para complacer a Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase Configurado desde AppDelegate!")
        return true
    }
}

class AuthViewModel: ObservableObject {
    @Published var user: User?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        self.authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error al cerrar sesión: %@", signOutError)
        }
    }
}

@main
struct TallerApp: App {
    // 2. Inyectamos el adaptador. Esto elimina el warning de "App Delegate does not conform..."
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some Scene {
        WindowGroup {
            if authViewModel.user != nil {
                MainView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            } else {
                LoginView()
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
    }
}
