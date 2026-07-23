//
//  SettingsView.swift
//  VTM
//
//  设置页面：外观 → 激活 → 模型 → 语言 → 翻译 → Siri → 关于
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var strings = AppStrings.shared
    @AppStorage("sourceLanguage") private var sourceLanguage = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage = "en-US"
    @AppStorage("autoPlayTranslation") private var autoPlay = true
    @AppStorage("autoDetectLanguage") private var autoDetectLanguage = true
    @AppStorage("conversationMode") private var conversationMode = false
    @AppStorage("appColorScheme") private var appColorScheme = "system"
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @State private var showActivationSheet = false
    @StateObject private var activationManager = ActivationManager.shared

    let languages: [(String, String)] = [
        ("中文", "zh-CN"),
        ("English", "en-US"),
        ("日本語", "ja-JP"),
        ("한국어", "ko-KR"),
        ("Español", "es-ES"),
        ("Français", "fr-FR"),
        ("Deutsch", "de-DE"),
        ("Português", "pt-PT"),
        ("Русский", "ru-RU"),
        ("العربية", "ar-SA"),
        ("Italiano", "it-IT"),
        ("Nederlands", "nl-NL"),
        ("Polski", "pl-PL"),
        ("Türkçe", "tr-TR"),
        ("ไทย", "th-TH"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 外观
                Section {
                    Picker(selection: $appColorScheme) {
                        HStack { Image(systemName: "iphone.gen2"); Text(L10n: "跟随系统") }.tag("system")
                        HStack { Image(systemName: "sun.max"); Text(L10n: "浅色模式") }.tag("light")
                        HStack { Image(systemName: "moon"); Text(L10n: "深色模式") }.tag("dark")
                    } label: { Text(L10n: "外观模式") }
                } header: { Text(L10n: "外观") }

                // MARK: - 激活
                Section {
                    activationSection
                } header: { Text(L10n: "激活") }

                // MARK: - 模型 & 数据（提前到这里，用户能一眼看到）
                Section {
                    NavigationLink {
                        ModelManagementView()
                    } label: {
                        HStack {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundColor(.blue)
                            Text(L10n: "模型管理")
                        }
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text(L10n: "翻译历史")
                        }
                    }
                } header: { Text(L10n: "模型 & 数据") }

                // MARK: - 应用语言
                Section {
                    Picker(selection: $appLanguage) {
                        Text(L10n: "中文").tag("zh-Hans")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                        Text("Français").tag("fr")
                    } label: { Text(L10n: "应用语言") }
                    .onChange(of: appLanguage) { _, newLang in
                        AppStrings.shared.setLanguage(newLang)
                    }
                } header: { Text(L10n: "应用语言") }

                // MARK: - 翻译设置
                Section {
                    Picker(selection: $sourceLanguage) {
                        ForEach(languages, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    } label: { Text(L10n: "源语言") }

                    Picker(selection: $targetLanguage) {
                        ForEach(languages, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    } label: { Text(L10n: "目标语言") }

                    Toggle(isOn: $autoPlay) { Text(L10n: "翻译后自动播放语音") }
                    Toggle(isOn: $autoDetectLanguage) { Text(L10n: "自动检测源语言") }
                    Toggle(isOn: $conversationMode) { Text(L10n: "对话模式") }
                } header: { Text(L10n: "翻译设置") }

                // MARK: - Siri 快捷指令
                Section {
                    HStack {
                        Image(systemName: "waveform.circle")
                            .foregroundColor(.purple).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n: "Siri 快捷指令").font(.body)
                            Text(L10n: "对 Siri 说「用VTM翻译」即可快速翻译文本")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                } header: { Text(L10n: "Siri 集成") }
                footer: {
                    Text(L10n: "支持 iOS 16+，可在系统「快捷指令」App 中管理")
                        .font(.caption2).foregroundColor(.secondary)
                }

                // MARK: - 数据管理
                Section {
                    Button { resetSettings() } label: {
                        Text(L10n: "重置设置")
                    }
                } header: { Text(L10n: "数据管理") }

                // MARK: - 关于
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle").foregroundColor(.blue)
                            Text(L10n: "关于 VTM")
                            Spacer()
                            Text(verbatim: "1.0.0").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        LegalView()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text").foregroundColor(.blue)
                            Text(L10n: "法律信息")
                        }
                    }

                    Button {
                        if let url = URL(string: "mailto:azhang364@gmail.com?subject=VTM%20Feedback%20v1.0") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope").foregroundColor(.blue)
                            Text(L10n: "发送反馈")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                } header: { Text(L10n: "关于") }
            }
            .navigationTitle(Text(L10n: "设置"))
            .sheet(isPresented: $showActivationSheet) {
                ActivationCodeSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .vtmActivationDidComplete)) { _ in
                activationManager.refreshState()
            }
        }
    }

    // MARK: - 激活区域
    private var activationSection: some View {
        HStack {
            Label {
                if activationManager.isActivated {
                    Text(L10n: "已激活 ✓").foregroundColor(.green)
                } else {
                    let days = activationManager.trialDaysRemaining
                    Text("剩余 \(days) 天免费试用").foregroundColor(.blue)
                }
            } icon: {
                Image(systemName: activationManager.isActivated ? "checkmark.seal.fill" : "key.fill")
                    .foregroundColor(activationManager.isActivated ? .green : .orange)
            }
            Spacer()
            if !activationManager.isActivated {
                Button { showActivationSheet = true } label: {
                    Text(L10n: "立即激活")
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions
    private func resetSettings() {
        UserDefaults.standard.removeObject(forKey: "sourceLanguage")
        UserDefaults.standard.removeObject(forKey: "targetLanguage")
        UserDefaults.standard.removeObject(forKey: "autoPlayTranslation")
        UserDefaults.standard.removeObject(forKey: "autoDetectLanguage")
        UserDefaults.standard.removeObject(forKey: "conversationMode")
        sourceLanguage = "zh-CN"
        targetLanguage = "en-US"
        autoPlay = true
        autoDetectLanguage = true
        conversationMode = false
    }
}
