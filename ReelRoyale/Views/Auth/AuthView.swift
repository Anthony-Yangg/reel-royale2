import SwiftUI

struct AuthView: View {
    @State private var isShowingLogin = true
    
    var body: some View {
        ZStack {
            // Background - Dark navy gradient
            LinearGradient(
                colors: [Color.navyDark, Color.navyPrimary, Color.navyLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Decorative elements - playful bubbles
            GeometryReader { geometry in
                Circle()
                    .fill(Color.aquaHighlight.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -100)
                
                Circle()
                    .fill(Color.coralAccent.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                
                Circle()
                    .fill(Color.sunnyYellow.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .offset(x: geometry.size.width * 0.6, y: geometry.size.height * 0.3)
            }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo section
                    VStack(spacing: 16) {
                        ZStack {
                            // Glow effect behind logo
                            Circle()
                                .fill(Color.aquaHighlight.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                            
                            Image(systemName: "fish.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.aquaHighlight, Color.coralAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("Reel Royale")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Claim your throne")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.aquaHighlight)
                    }
                    .padding(.top, 60)
                    
                    // Auth toggle - pill style
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isShowingLogin = true
                            }
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(isShowingLogin ? .navyPrimary : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(isShowingLogin ? Color.white : Color.clear)
                                )
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isShowingLogin = false
                            }
                        } label: {
                            Text("Sign Up")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(!isShowingLogin ? .navyPrimary : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(!isShowingLogin ? Color.white : Color.clear)
                                )
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
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

