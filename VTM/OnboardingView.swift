//
//  OnboardingView.swift
//  VTM
//
//  Created by 张恒郡 on 2026-05-11.
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @ObservedObject private var strings = AppStrings.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step: Int = 0
    
    var body: some View {
        VStack {
            if step == 0 {
                WelcomePageView(onNext: { step = 1 })
            } else {
                PrivacyConsentView(
                    onAccept: { hasCompletedOnboarding = true },
                    onDecline: { exit(0) }
                )
            }
        }
        .animation(.easeInOut, value: step)
    }
}

struct WelcomePageView: View {
    @ObservedObject private var strings = AppStrings.shared
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.blue)
            
            Text(L10n: "欢迎使用 VTM")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(L10n: "您的智能语音翻译助手")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                Text(L10n: "开始使用")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(PulseButtonStyle())
            .padding(.horizontal, 50)
            .padding(.bottom, 50)
        }
    }
}

struct PermissionPageView: View {
    @ObservedObject private var strings = AppStrings.shared
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                Button(action: onNext) {
                    Text(L10n: "下一步")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 40)
            }
        }
    }
}

struct PrivacyConsentView: View {
    @ObservedObject private var strings = AppStrings.shared
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var showFullPrivacyPolicy = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 80)
                
                Image(systemName: "hand.raised.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text(L10n: "隐私政策与使用条款")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(L10n: "请阅读并同意我们的隐私政策和使用条款以继续使用 VTM")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 12) {
                    PrivacyPointView(icon: "wifi.slash", text: "完全离线，无需网络连接")
                    PrivacyPointView(icon: "lock.shield.fill", text: "所有数据仅存储在本地设备")
                    PrivacyPointView(icon: "hand.raised.slash", text: "不收集、不出售、不共享个人数据")
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                Button(action: {
                    showFullPrivacyPolicy = true
                }) {
                    Text(L10n: "查看完整隐私政策")
                        .font(.callout)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showFullPrivacyPolicy) {
                    LegalView()
                }
                
                Button(action: onAccept) {
                    Text(L10n: "同意并继续")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 50)
                .padding(.top, 10)
                
                Button(action: onDecline) {
                    Text(L10n: "不同意并退出")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 40)
            .padding()
        }
    }
}

struct PrivacyPointView: View {
    @ObservedObject private var strings = AppStrings.shared
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(verbatim: text)
                .font(.callout)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Pulse Button Style

struct PulseButtonStyle: ButtonStyle {
    @State private var isPulsing = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : (isPulsing ? 1.03 : 1.0))
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Microphone Permission View
struct MicrophonePermissionView: View {
    @ObservedObject private var strings = AppStrings.shared
    let onDone: () -> Void
    @State private var hasRequestedPermission = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.blue)

            Text("麦克风权限")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(L10n: "VTM 需要访问麦克风以进行语音翻译。\n所有音频仅在本地设备处理，不会上传至任何服务器。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                guard !hasRequestedPermission else {
                    onDone()
                    return
                }
                hasRequestedPermission = true
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    DispatchQueue.main.async { onDone() }
                }
            }) {
                Text("允许麦克风权限")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 50)
        }
    }
}

#Preview {
    OnboardingView()
}
