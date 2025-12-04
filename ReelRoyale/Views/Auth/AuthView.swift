import SwiftUI

struct AuthView: View {
    @State private var isShowingLogin = true
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.deepOcean, Color.oceanBlue],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Decorative elements
            GeometryReader { geometry in
                Circle()
                    .fill(Color.seafoam.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -100)
                
                Circle()
                    .fill(Color.coral.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
            }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo section
                    VStack(spacing: 16) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.seafoam, Color.coral],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Reel Royale")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Claim your throne")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    
                    // Auth toggle
                    HStack(spacing: 0) {
                        Button {
                            withAnimation {
                                isShowingLogin = true
                            }
                        } label: {
                            Text("Sign In")
                                .fontWeight(.semibold)
                                .foregroundColor(isShowingLogin ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isShowingLogin ? Color.white.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                        
                        Button {
                            withAnimation {
                                isShowingLogin = false
                            }
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(!isShowingLogin ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(!isShowingLogin ? Color.white.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    
                    // Auth form
                    if isShowingLogin {
                        LoginView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        SignUpView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
}

#Preview {
    AuthView()
}

