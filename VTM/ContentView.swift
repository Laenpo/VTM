//
//  ContentView.swift
//  VTM
//
//  主界面 — 底部 2 Tab 布局（全屏无边距）
//  Tab 1: 翻译 (语音识别 + 翻译 + TTS)
//  Tab 2: 设置 (语言 / 模型管理 / 关于)
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var strings = AppStrings.shared
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    @EnvironmentObject var translator: Translator

    @State private var selectedTab = 0
    @SceneStorage("selectedTab") private var savedTab = 0

    init() {
        // 全屏无边界 TabBar：透明背景，去掉分割线
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1 — 翻译
            TranslationView()
                .tabItem {
                    Label(L10n: "翻译", systemImage: "translate")
                }
                .tag(0)

            // Tab 2 — 设置
            SettingsView()
                .tabItem {
                    Label(L10n: "设置", systemImage: "gear")
                }
                .tag(1)
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            selectedTab = savedTab
        }
        .onChange(of: selectedTab) { _, newTab in
            savedTab = newTab
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSettingsTab"))) { _ in
            selectedTab = 1
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SpeechRecognizer())
        .environmentObject(Translator())
        .environmentObject(TTSManager())
}
