import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showForgotPassword = false
    
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
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                        .textContentType(.password)
                        .foregroundColor(.white)
                        .accentColor(.seafoam)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Forgot password
            HStack {
                Spacer()
                Button {
                    showForgotPassword = true
                } label: {
                    Text("Forgot password?")
                        .font(.caption)
                        .foregroundColor(.seafoam)
                }
            }
            
            // Sign in button
            Button {
                Task {
                    await viewModel.signIn()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.coral, Color.sunset],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || !viewModel.canSignIn)
            .opacity(viewModel.canSignIn ? 1 : 0.6)
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $viewModel.email)
            Button("Send Reset Link") {
                Task {
                    await viewModel.resetPassword()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
    }
}

#Preview {
    ZStack {
        Color.deepOcean.ignoresSafeArea()
        LoginView()
    }
}

