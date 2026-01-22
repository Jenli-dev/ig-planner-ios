import SwiftUI

/// Демо-флоу подключения Instagram Business Account
/// Ничего реально не логинит, только показывает визуальный путь для Meta.
struct IGConnectDemoView: View {
    @State private var step: Step = .start
    
    enum Step {
        case start          // экран с кнопкой "Connect Instagram Business Account"
        case login          // "Meta login" с кнопкой Continue
        case choosePage     // выбор Facebook Page
        case chooseIG       // выбор Instagram Business Account
        case done           // успех + кнопка "Go to app"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // бренд-фон
                Color.clear
                    .brandBackground()
                    .ignoresSafeArea()
                
                content
                    .padding(20)
            }
            .navigationTitle("Connect Instagram")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch step {
        case .start:
            startStep
        case .login:
            loginStep
        case .choosePage:
            choosePageStep
        case .chooseIG:
            chooseIGStep
        case .done:
            doneStep
        }
    }
    
    // MARK: - Шаг 1: экран в приложении
    private var startStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 56))
                .foregroundColor(.white)
                .padding()
                .background(.white.opacity(0.15), in: Circle())
            
            Text("Connect Instagram Business Account")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("We’ll open Meta window where you can choose your Facebook Page and linked Instagram Business Account.")
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut) {
                    step = .login
                }
            } label: {
                Text("Connect Instagram Business Account")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Шаг 2: окно Meta Login (визуальная имитация)
    private var loginStep: some View {
        VStack(spacing: 16) {
            metaHeader
            
            Text("Log in with Facebook")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("To continue, log in with Facebook so we can show you your Pages and Instagram accounts.")
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut) {
                    step = .choosePage
                }
            } label: {
                Text("Continue with Facebook")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
            }
            
            Button {
                // для видео можно нажать Back, если что
                withAnimation(.easeInOut) {
                    step = .start
                }
            } label: {
                Text("Cancel")
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(20)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Шаг 3: выбор Facebook Page
    private var choosePageStep: some View {
        VStack(spacing: 16) {
            metaHeader
            
            Text("Choose a Page")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select the Facebook Page that is connected to your Instagram Business Account.")
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            VStack(spacing: 10) {
                pageRow(title: "Planza Analytics", selected: true)
                pageRow(title: "My Test Page", selected: false)
            }
            .padding(.top, 8)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut) {
                    step = .chooseIG
                }
            } label: {
                Text("Next")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Шаг 4: выбор IG Business Account
    private var chooseIGStep: some View {
        VStack(spacing: 16) {
            metaHeader
            
            Text("Choose Instagram Account")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select the Instagram Business or Creator account you want to connect.")
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            VStack(spacing: 10) {
                igRow(handle: "@planza.analytics", selected: true)
                igRow(handle: "@test_creator_account", selected: false)
            }
            .padding(.top, 8)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut) {
                    step = .done
                }
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Шаг 5: успех
    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .shadow(radius: 8)
            
            Text("Instagram Business Account Connected")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text("You can now schedule posts, track analytics and use all Planza tools for this account.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Button {
                // после записи видео можно вернуться к первому экрану;
                // в реальном приложении здесь можно закрывать флоу
                withAnimation(.easeInOut) {
                    step = .start
                }
            } label: {
                Text("Go to app")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundColor(.white)
            }
        }
        .padding(24)
    }
    
    // MARK: - Вспомогательные вью
    
    private var metaHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .overlay(
                    Text("f")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.blue)
                )
            Text("Meta")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private func pageRow(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func igRow(handle: String, selected: Bool) -> some View {
        HStack {
            Image(systemName: "person.crop.circle")
                .foregroundColor(.white)
            Text(handle)
                .foregroundColor(.white)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
