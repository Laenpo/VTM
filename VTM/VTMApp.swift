//
//  VTMApp.swift
//  VTM
//
//  应用入口 — 环境对象注入 + 模型自动加载
//

import SwiftUI
import AVFoundation

@main
struct VTMApp: App {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var translator = Translator()
    @StateObject private var appStrings = AppStrings.shared

    @AppStorage("appColorScheme") private var appColorScheme = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasAppeared = false
    @State private var languageID = UUID()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Bundle.enableLanguageSwitching()
    }

    var body: some Scene {
        WindowGroup {
            let sr = speechRecognizer
            let tr = translator

            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .id(languageID)
                        .environmentObject(sr)
                        .environmentObject(ttsManager)
                        .environmentObject(tr)
                        .environmentObject(appStrings)
                        .environment(\.locale, appStrings.locale)
                        .preferredColorScheme(colorScheme)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppStringsLanguageDidChange"))) { _ in
                            languageID = UUID()
                        }
                        .onAppear {
                            guard !hasAppeared else { return }
                            hasAppeared = true

#if DEBUG
                            CrashDiagnostics.reportLastCrash()
                            CrashDiagnostics.log("APP.LAUNCH: VTM started")
                            CrashDiagnostics.logMemory(tag: "launch")
#endif

                            VTMLog.app("🚀 VTM 启动")

                            ActivationManager.shared.setFirstLaunchDateIfNeeded()

                            Task {
                                VTMLog.model("🔄 自动加载 Whisper 模型...")
                                await sr.loadDefaultModel()
                                VTMLog.model("✅ Whisper 加载完成: \(sr.isModelLoaded)")
                            }

                            tr.prewarmMLKit()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ModelDownloaded"))) { _ in
                            Task {
                                VTMLog.download("📦 模型下载完成通知 — 开始加载")
                                CrashDiagnostics.log("APP.ModelDownloaded: notification received, isModelLoaded=\(sr.isModelLoaded)")
                                CrashDiagnostics.logMemory(tag: "download.notify")

                                if !sr.isModelLoaded {
                                    await sr.loadDefaultModel()
                                    CrashDiagnostics.log("APP.ModelDownloaded: Whisper loaded=\(sr.isModelLoaded)")
                                } else {
                                    CrashDiagnostics.log("APP.ModelDownloaded: Whisper already loaded, skipping")
                                }
                                tr.prewarmMLKit()

                                VTMLog.download("✅ 下载后加载完成 — Whisper: \(sr.isModelLoaded)")
                                CrashDiagnostics.logMemory(tag: "download.complete")
                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .background || newPhase == .inactive {
                                CrashDiagnostics.closeFile()
                            }
                        }
                } else {
                    OnboardingView()
                }
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
