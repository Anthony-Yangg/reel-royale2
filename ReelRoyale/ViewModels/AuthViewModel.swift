import Foundation
import SwiftUI

/// ViewModel for authentication screens
@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Profile setup
    @Published var username = ""
    @Published var homeLocation = ""
    @Published var bio = ""
    @Published var avatarImage: UIImage?
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let imageUploadService: ImageUploadServiceProtocol
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol? = nil,
        imageUploadService: ImageUploadServiceProtocol? = nil
    ) {
        self.authService = authService ?? AppState.shared.authService
        self.imageUploadService = imageUploadService ?? AppState.shared.imageUploadService
    }
    
    // MARK: - Validation
    
    var isEmailValid: Bool {
        email.isValidEmail
    }
    
    var isPasswordValid: Bool {
        password.count >= 8
    }
    
    var doPasswordsMatch: Bool {
        password == confirmPassword
    }
    
    var canSignIn: Bool {
        isEmailValid && !password.isEmpty
    }
    
    var canSignUp: Bool {
        isEmailValid && isPasswordValid && doPasswordsMatch
    }
    
    var isUsernameValid: Bool {
        username.count >= 3 && username.count <= 20
    }
    
    var canCompleteProfile: Bool {
        isUsernameValid
    }
    
    // MARK: - Actions
    
    func signIn() async {
        guard canSignIn else {
            showError(message: "Please enter a valid email and password")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            AppState.shared.updateCurrentUser(user)
            clearForm()
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func signUp() async {
        guard canSignUp else {
            if !isEmailValid {
                showError(message: "Please enter a valid email address")
            } else if !isPasswordValid {
                showError(message: "Password must be at least 8 characters")
            } else if !doPasswordsMatch {
                showError(message: "Passwords do not match")
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password)
            
            // Ensure we have an active session; if email confirmation is enabled, session may be nil
            let session = await AppState.shared.supabaseService.currentSession
            if session == nil {
                // No session yet (likely email confirmation flow). Ask user to confirm and sign in.
                AppState.shared.isAuthenticated = false
                AppState.shared.needsProfileSetup = false
                showError(message: "Check your email to confirm your account, then sign in to continue.")
            } else {
                AppState.shared.currentUser = user
                AppState.shared.needsProfileSetup = true
                AppState.shared.isAuthenticated = true
                clearForm()
            }
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func completeProfileSetup() async {
        guard canCompleteProfile else {
            showError(message: "Username must be 3-20 characters")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check username availability
            let isAvailable = try await authService.isUsernameAvailable(username)
            guard isAvailable else {
                showError(message: "Username is already taken")
                isLoading = false
                return
            }
            
            // Upload avatar if selected
            var avatarURL: String?
            if let image = avatarImage,
               let userId = AppState.shared.currentUser?.id {
                avatarURL = try await imageUploadService.uploadAvatar(image, for: userId)
            }
            
            // Update profile
            let user = try await authService.updateProfile(
                username: username,
                avatarURL: avatarURL,
                homeLocation: homeLocation.isEmpty ? nil : homeLocation,
                bio: bio.isEmpty ? nil : bio
            )
            
            AppState.shared.updateCurrentUser(user)
            clearProfileForm()
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func resetPassword() async {
        guard isEmailValid else {
            showError(message: "Please enter a valid email address")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.resetPassword(email: email)
            showError(message: "Password reset email sent. Check your inbox.")
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func signOut() async {
        await AppState.shared.signOut()
    }
    
    // MARK: - Helpers
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }
    
    private func clearProfileForm() {
        username = ""
        homeLocation = ""
        bio = ""
        avatarImage = nil
    }
}

