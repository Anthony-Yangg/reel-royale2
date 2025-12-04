import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.white.opacity(0.5))
                    
                    TextField("", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(.white)
                        .accentColor(.seafoam)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.email.isEmpty || viewModel.isEmailValid ? Color.white.opacity(0.2) : Color.coral, lineWidth: 1)
                )
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white.opacity(0.5))
                    
                    SecureField("", text: $viewModel.password)
                        .textContentType(.newPassword)
                        .foregroundColor(.white)
                        .accentColor(.seafoam)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.password.isEmpty || viewModel.isPasswordValid ? Color.white.opacity(0.2) : Color.coral, lineWidth: 1)
                )
                
                if !viewModel.password.isEmpty && !viewModel.isPasswordValid {
                    Text("Password must be at least 8 characters")
                        .font(.caption2)
                        .foregroundColor(.coral)
                }
            }
            
            // Confirm password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white.opacity(0.5))
                    
                    SecureField("", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .foregroundColor(.white)
                        .accentColor(.seafoam)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.confirmPassword.isEmpty || viewModel.doPasswordsMatch ? Color.white.opacity(0.2) : Color.coral, lineWidth: 1)
                )
                
                if !viewModel.confirmPassword.isEmpty && !viewModel.doPasswordsMatch {
                    Text("Passwords do not match")
                        .font(.caption2)
                        .foregroundColor(.coral)
                }
            }
            
            // Sign up button
            Button {
                Task {
                    await viewModel.signUp()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.seafoam, Color.oceanBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || !viewModel.canSignUp)
            .opacity(viewModel.canSignUp ? 1 : 0.6)
            .padding(.top, 8)
            
            // Terms
            Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ZStack {
        Color.deepOcean.ignoresSafeArea()
        SignUpView()
    }
}

