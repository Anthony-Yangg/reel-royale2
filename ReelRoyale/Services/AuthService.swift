import Foundation
import Supabase

/// Protocol for authentication operations
protocol AuthServiceProtocol {
    /// Sign up with email and password
    func signUp(email: String, password: String) async throws -> User
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User
    
    /// Sign out current user
    func signOut() async throws
    
    /// Get current authenticated user
    func getCurrentUser() async throws -> User?
    
    /// Update user profile
    func updateProfile(username: String, avatarURL: String?, homeLocation: String?, bio: String?) async throws -> User
    
    /// Reset password
    func resetPassword(email: String) async throws
    
    /// Check if email is available
    func isEmailAvailable(_ email: String) async throws -> Bool
    
    /// Check if username is available
    func isUsernameAvailable(_ username: String) async throws -> Bool
}

/// Supabase implementation of AuthService
final class SupabaseAuthService: AuthServiceProtocol {
    private let supabase: SupabaseService
    private let userRepository: UserRepositoryProtocol
    
    init(supabase: SupabaseService, userRepository: UserRepositoryProtocol) {
        self.supabase = supabase
        self.userRepository = userRepository
    }
    
    func signUp(email: String, password: String) async throws -> User {
        // Create auth user
        let authResponse = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        let user = authResponse.user
        
        // The user profile is created automatically by the handle_new_user trigger in Supabase.
        // We just need to fetch the newly created profile. Add retry + manual fallback in case of trigger delay.
        var userProfile: User?
        for _ in 0..<3 {
            userProfile = try await userRepository.getUser(byId: user.id.uuidString)
            if userProfile != nil {
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        if userProfile == nil {
            let fallback = User(
                id: user.id.uuidString,
                username: "",
                createdAt: Date()
            )
            try await userRepository.createUser(fallback)
            userProfile = try await userRepository.getUser(byId: user.id.uuidString)
        }
        
        guard let finalUserProfile = userProfile else {
            throw AppError.notFound("Newly created user profile could not be found.")
        }
        
        // Notify app of login
        NotificationCenter.default.post(name: .userDidLogin, object: nil)
        
        return finalUserProfile
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        // session.user is non-optional, so we can access it directly.
        // Fetch the profile with a short retry; if still missing, create a minimal profile.
        var userProfile: User?
        for _ in 0..<3 {
            userProfile = try await userRepository.getUser(byId: session.user.id.uuidString)
            if userProfile != nil { break }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        if userProfile == nil {
            let fallback = User(
                id: session.user.id.uuidString,
                username: "",
                createdAt: Date()
            )
            try await userRepository.createUser(fallback)
            userProfile = try await userRepository.getUser(byId: session.user.id.uuidString)
        }
        
        guard let finalUserProfile = userProfile else {
            throw AppError.notFound("User profile")
        }
        
        // Notify app of login
        NotificationCenter.default.post(name: .userDidLogin, object: nil)
        
        return finalUserProfile
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    func getCurrentUser() async throws -> User? {
        guard let session = await supabase.currentSession else {
            return nil
        }
        
        return try await userRepository.getUser(byId: session.user.id.uuidString)
    }
    
    func updateProfile(username: String, avatarURL: String?, homeLocation: String?, bio: String?) async throws -> User {
        guard let userId = await supabase.currentUserId else {
            throw AppError.unauthorized
        }
        
        guard var user = try await userRepository.getUser(byId: userId) else {
            throw AppError.notFound("User profile")
        }
        
        user.username = username
        user.avatarURL = avatarURL
        user.homeLocation = homeLocation
        user.bio = bio
        user.updatedAt = Date()
        
        try await userRepository.updateUser(user)
        
        return user
    }
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    func isEmailAvailable(_ email: String) async throws -> Bool {
        // This would typically be checked via a custom RPC or edge function
        // For now, return true - Supabase will handle duplicate email errors
        return true
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let existing = try await userRepository.getUser(byUsername: username)
        return existing == nil
    }
}

