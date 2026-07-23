//
//  TranslationView.swift
//  VTM
//
//  翻译主界面 — 按住说话 + 识别 + 翻译 + TTS
//  按住录音，松手自动翻译并播放
//

import SwiftUI
import UIKit
import AVFoundation
import Combine
import NaturalLanguage

struct TranslationView: View {
    @ObservedObject private var strings = AppStrings.shared
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    @EnvironmentObject private var translator: Translator
    @EnvironmentObject private var ttsManager: TTSManager

    @State private var sourceText: String = ""
    @State private var translatedText: String = ""

    /// 翻译完成后是否自动播放
    @AppStorage("autoPlayTranslation") private var autoPlay = true

    /// 是否自动检测源语言
    @AppStorage("autoDetectLanguage") private var autoDetectLanguage = true

    /// 对话模式：双人交替翻译
    @AppStorage("conversationMode") private var conversationMode = false

    /// 对话模式当前翻译方向（A→B 或 B→A）
    @State private var conversationDirectionIsAToB = true

    /// 是否正在按住录音 (使用 @State，不用 GestureState)
    @State private var isPressing = false

    /// 是否正在转写中（松手后 → 转录完成前）
    @State private var isTranscribing = false

    /// 页面级错误消息（置顶显示，可关闭）
    @State private var topErrorMessage: String?
    @State private var showTopError = false

    /// 行内语言选择器
    @State private var showSourceLanguagePicker = false
    @State private var showTargetLanguagePicker = false

    /// 复制成功 toast
    @State private var showCopyToast = false

    /// 麦克风权限被拒绝提示
    @State private var showMicDeniedAlert = false

    /// 上滑取消录音
    @State private var dragTranslation: CGSize = .zero
    @State private var isCancelZone = false

    /// 模型加载倒计时
    @State private var modelLoadingSeconds = 0
    @State private var isModelLoading = false
    @State private var modelLoadTimer: Timer?

    /// 正在重新加载 Whisper（NLLB 使用后被卸载了）
    @State private var isReloadingWhisper = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // 全屏背景
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // MARK: - 标题 + 引擎状态（双指示器）
                        headerSection
                            .padding(.top, 0)
                            .padding(.bottom, 6)

                        // MARK: - 语言标识（可点击切换 + 交换按钮）
                        languageBar
                            .padding(.bottom, 16)

                        // 将识别/翻译结果稍微下推
                        Spacer().frame(height: 12)

                        // MARK: - 识别文本（自适应高度）
                        sourceTextSection
                            .padding(.bottom, 10)

                        // MARK: - 翻译结果（自适应高度）
                        translatedTextSection

                        // 避免太贴底部按钮，留少量呼吸空间
                        Spacer(minLength: 60)

                        // MARK: - 录音区域
                        if speechRecognizer.isModelLoaded {
                            if conversationMode {
                                conversationButtonArea
                            } else {
                                recordButtonArea
                            }
                        } else if isReloadingWhisper || isModelLoading {
                            whisperLoadingView
                        } else {
                            modelNotLoadedView
                        }
                    }
                    .frame(minHeight: geometry.size.height - geometry.safeAreaInsets.bottom)
                    .padding(.horizontal, 14)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - 顶部错误横幅（浮层，不占用布局空间）
                if showTopError, let msg = topErrorMessage {
                    topErrorBanner(msg)
                }
            }
        }
        .onAppear {
            // 自动恢复：如果内存警告导致 Whisper 被卸载，且模型文件存在 → 重新加载
            recoverWhisperIfNeeded()
            // 📲 Siri Shortcuts 传入的文本
            readSiriTranslateText()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ModelDownloaded"))) { _ in
            // 下载完成 → 开始加载倒计时
            isModelLoading = true
            modelLoadingSeconds = 0
            modelLoadTimer?.invalidate()
            modelLoadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if speechRecognizer.isModelLoaded {
                    modelLoadTimer?.invalidate()
                    modelLoadTimer = nil
                    isModelLoading = false
                } else {
                    modelLoadingSeconds += 1
                }
            }
        }
        .onChange(of: speechRecognizer.isModelLoaded) { _, loaded in
            if loaded {
                modelLoadTimer?.invalidate()
                modelLoadTimer = nil
                isModelLoading = false
            }
        }
        .onChange(of: speechRecognizer.transcribedText) { _, newValue in
            sourceText = newValue
        }
        .onChange(of: speechRecognizer.errorMessage) { _, newValue in
            if let err = newValue {
                showTopErrorMessage(err)
            }
        }
        .onChange(of: speechRecognizer.isRecording) { _, newValue in
            if !newValue {
                // 录音结束 → 进入转写中状态
                isTranscribing = true
            }
        }
        // 行内语言选择器 Sheet
        .sheet(isPresented: $showSourceLanguagePicker) {
            LanguagePickerView(
                title: "选择源语言",
                currentLanguage: translator.sourceLanguage,
                onSelect: { code in
                    translator.setLanguages(source: code, target: translator.targetLanguage)
                },
                isSourcePicker: true
            )
        }
        .sheet(isPresented: $showTargetLanguagePicker) {
            LanguagePickerView(
                title: "选择目标语言",
                currentLanguage: translator.targetLanguage,
                onSelect: { code in
                    translator.setLanguages(source: translator.sourceLanguage, target: code)
                },
                isSourcePicker: false
            )
        }
    }

    // MARK: - 顶部错误横幅

    private func topErrorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(3)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTopError = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 18))
                }
            }
            .padding(12)
            .background(Color.red.opacity(0.92))
            .cornerRadius(10)
            .shadow(color: .red.opacity(0.3), radius: 4)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: showTopError)
        .zIndex(100)
    }

    private func showTopErrorMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            topErrorMessage = message
            showTopError = true
        }
        // 5 秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if topErrorMessage == message {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTopError = false
                }
            }
        }
    }

    // MARK: - 标题区 (三引擎状态指示: Whisper + ML Kit + NLLB)

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text(L10n: "VTM 语音翻译")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 10) {
                // Whisper 状态
                engineChip(
                    icon: "waveform.circle.fill",
                    label: "Whisper",
                    isReady: speechRecognizer.isModelLoaded,
                    badge: "必需"
                )

                // ML Kit 主力翻译引擎
                if translator.isUsingMLKit {
                    if translator.isMLKitDownloading {
                        engineChip(
                            icon: "arrow.down.circle.fill",
                            label: "ML Kit · 下载中",
                            isReady: false
                        )
                    } else {
                        engineChip(
                            icon: "sparkles",
                            label: "ML Kit",
                            isReady: true
                        )
                    }
                }

                // NLLB 后备引擎
                if translator.isNLLBReady {
                    engineChip(
                        icon: "globe.asia.australia.fill",
                        label: LocalizedStringKey(translator.isUsingMLKit ? "NLLB 后备" : "NLLB-200"),
                        isReady: true,
                        isFallback: translator.isUsingMLKit,
                        badge: "后备"
                    )
                } else if translator.isNLLBLoading {
                    engineChip(
                        icon: "hourglass",
                        label: "NLLB · 加载中",
                        isReady: false,
                        badge: "后备"
                    )
                } else if translator.isNLLBDownloaded {
                    engineChip(
                        icon: "tray.full",
                        label: "NLLB · 备用",
                        isReady: false,
                        badge: "后备"
                    )
                } else {
                    engineChip(
                        icon: "globe.asia.australia.fill",
                        label: "NLLB",
                        isReady: false,
                        badge: "后备"
                    )
                }
            }
        }
    }

    private func engineChip(icon: String, label: LocalizedStringKey, isReady: Bool, isFallback: Bool = false, badge: String? = nil) -> some View {
        let baseColor: Color = isReady ? (isFallback ? .gray : .green) : .orange
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isReady ? (isFallback ? .secondary : .green) : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.adaptiveChipBg(base: baseColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.adaptiveChipBorder(base: baseColor), lineWidth: 0.5)
            )

            // 🏷 角标（"必需"/"后备"）
            if let badge = badge {
                Text(LocalizedStringKey(badge))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(badge == "必需" ? Color.blue : Color.gray)
                    .cornerRadius(4)
                    .offset(x: 4, y: -6)
            }
        }
    }

    // MARK: - 语言标识（可点击切换 + 交换按钮）

    private var languageBar: some View {
        HStack(spacing: 8) {
            // 源语言（可点击）
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showSourceLanguagePicker = true
            } label: {
                HStack(spacing: 4) {
                    if autoDetectLanguage {
                        Text(L10n: "自动")
                            .font(.headline)
                            .foregroundColor(.blue)
                    } else {
                        Text(translator.sourceLanguageDisplay)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.adaptiveBlueTranslucent)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // 交换按钮
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    translator.setLanguages(
                        source: translator.targetLanguage,
                        target: translator.sourceLanguage
                    )
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // 目标语言（可点击）
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showTargetLanguagePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(translator.targetLanguageDisplay)
                        .font(.headline)
                        .foregroundColor(.green)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.green.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.adaptiveGreenMedium)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // 对话模式切换
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.easeInOut(duration: 0.25)) {
                    conversationMode.toggle()
                }
                if conversationMode {
                    // 记住进入对话模式前的源语言
                    UserDefaults.standard.set(translator.sourceLanguage, forKey: "conversationSourceLang")
                    conversationDirectionIsAToB = true
                }
            } label: {
                Image(systemName: conversationMode ? "person.2.fill" : "person.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(conversationMode ? .blue : .secondary)
                    .padding(6)
                    .background(conversationMode ? Color.blue.opacity(0.12) : Color(.systemGray5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 识别结果

    private var sourceTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n: "识别结果", systemImage: "ear")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            ZStack {
                ScrollView {
                    Group {
                        if !sourceText.isEmpty {
                            Text(sourceText)
                        } else if isPressing {
                            Text(L10n: "正在聆听...")
                        } else {
                            Text(L10n: "按住下方按钮开始说话")
                        }
                    }
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut, value: sourceText)
                }
                .frame(minHeight: 90, maxHeight: 180)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // 🔄 "识别中..." 指示器 — 放在文本框内部居中位置
                if isTranscribing && sourceText.isEmpty {
                    VStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.orange)
                        HStack(spacing: 4) {
                            Text(L10n: "识别中")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            AnimatedDots()
                        }
                    }
                    .padding(16)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isTranscribing)
        }
    }

    // MARK: - 翻译结果

    private var translatedTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n: "翻译结果", systemImage: "text.bubble")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            ZStack {
                ScrollView {
                    HStack {
                        Group {
                            if !translatedText.isEmpty {
                                Text(translatedText)
                            } else if !isTranscribing {
                                Text(L10n: "翻译将显示在这里")
                            }
                        }
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !translatedText.isEmpty {
                            // 复制按钮 — 加大触控区域 + 背景
                            Button(action: {
                                UIPasteboard.general.string = translatedText
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopyToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showCopyToast = false
                                    }
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 4)

                            // TTS 播放按钮
                            Button(action: {
                                let lang = translator.targetLanguage == "zh" ? "zh-CN" : "en-US"
                                ttsManager.speak(text: translatedText, language: lang)
                            }) {
                                Image(systemName: ttsManager.isSpeaking
                                      ? "speaker.wave.2.fill"
                                      : "speaker.wave.2")
                                    .font(.title3)
                                    .foregroundColor(ttsManager.isSpeaking ? .green : .blue)
                                    .frame(width: 36, height: 36)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .animation(.easeInOut, value: translatedText)
                }
                .frame(minHeight: 90, maxHeight: 180)
                .background(Color.adaptiveGreenTranslucent)
                .cornerRadius(10)

                // 🎉 复制成功 Toast
                if showCopyToast {
                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(L10n: "已复制")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.adaptiveToastBg)
                        .cornerRadius(16)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .alert(AppStrings.shared.get("麦克风未开启"), isPresented: $showMicDeniedAlert) {
            Button(AppStrings.shared.get("前往设置")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(AppStrings.shared.get("取消"), role: .cancel) {}
        } message: {
            Text(L10n: "请在系统设置中允许 VTM 访问麦克风以使用语音翻译功能。")
        }
    }

    // MARK: - 录音区域

    private var recordButtonArea: some View {
        VStack(spacing: 8) {
            if !translator.isUsingMLKit && !translator.isNLLBReady {
                // 只有当前语言对需要 NLLB 时才警告（zh↔en 走 ML Kit，不需要 NLLB）
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    if translator.isNLLBLoading {
                        Text(L10n: "备用翻译模型加载中...")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if translator.isNLLBDownloaded {
                        Text(L10n: "备用翻译模型未加载")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text(L10n: "备用翻译模型未下载")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Button("去下载") {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SwitchToSettingsTab"),
                                object: nil
                            )
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 4)
            }

            ZStack {
                // 🌊 波纹扩散动画层（按住时显示）
                if isPressing {
                    ForEach(0..<3, id: \.self) { index in
                        RippleCircle(
                            color: Color.red,
                            delay: Double(index) * 0.25,
                            isPressing: $isPressing
                        )
                    }
                }

                // 外圈脉冲指示
                Circle()
                    .stroke(isPressing ? Color.red.opacity(0.35) : Color.blue.opacity(0.18),
                            lineWidth: 2.5)
                    .frame(width: isPressing ? 122 : 102, height: isPressing ? 122 : 102)
                    .scaleEffect(isPressing ? 1.15 : 1.0)

                // 主按钮
                Circle()
                    .fill(isPressing ? Color.red : Color.blue)
                    .frame(width: 82, height: 82)
                    .shadow(color: (isPressing ? Color.red : Color.blue).opacity(0.5),
                            radius: isPressing ? 14 : 10)

                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .scaleEffect(isPressing ? 0.9 : 1.0)
            }
            .scaleEffect(isPressing ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressing {
                            isPressing = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                startRecording()
                            }
                        }
                        // Track drag for cancel: if dragged up > 50pt, enter cancel zone
                        dragTranslation = value.translation
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCancelZone = value.translation.height < -50
                        }
                    }
                    .onEnded { _ in
                        let wasCancelled = isCancelZone
                        isPressing = false
                        isCancelZone = false
                        dragTranslation = .zero
                        if wasCancelled {
                            Task {
                                await speechRecognizer.stopRecording()
                                await MainActor.run {
                                    isTranscribing = false
                                    sourceText = ""
                                }
                            }
                        } else {
                            stopRecordingAndTranslate()
                        }
                    }
            )

            Group {
                if isPressing {
                    if isCancelZone {
                        Text(L10n: "松开取消")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else {
                        VStack(spacing: 2) {
                            Text(L10n: "松手翻译")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(L10n: "上滑取消")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                } else {
                    Text(L10n: "按住说话")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 对话模式按钮

    /// 对话模式：单按钮自动轮流切换翻译方向

    private var conversationButtonArea: some View {
        VStack(spacing: 10) {
            // 方向指示器
            HStack(spacing: 8) {
                Text(translator.sourceLanguageDisplay)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Image(systemName: conversationDirectionIsAToB ? "arrow.right" : "arrow.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(translator.targetLanguageDisplay)
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // 单按钮 — 按住说话
            recordButtonArea
        }
    }

    // MARK: - 模型未加载提示

    private var modelNotLoadedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange, .orange.opacity(0.35))
                .padding(.bottom, 2)

            Text(L10n: "需要下载语音识别模型")
                .font(.title3)
                .fontWeight(.semibold)

            Text(L10n: "Whisper 模型 (~466 MB) 用于离线语音识别\n下载后即可开始使用")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToSettingsTab"),
                    object: nil
                )
            } label: {
                Label(L10n: "前往设置下载模型", systemImage: "gearshape")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)
        }
        .padding(28)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    /// Whisper 加载中（含倒计时）
    private var whisperLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.3)
            Text(L10n: "重新加载语音识别模型...")
                .font(.headline)
            if isModelLoading && modelLoadingSeconds > 0 {
                Text(String(format: AppStrings.shared.get("模型加载中... %d 秒"), modelLoadingSeconds))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .contentTransition(.numericText())
                    .animation(.default, value: modelLoadingSeconds)
                Text(AppStrings.shared.get("首次加载大约需要 15 秒，请耐心等待"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(L10n: "翻译引擎释放内存后正在恢复\n请稍候片刻")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Actions

    /// 读取 Siri Shortcuts 传入的翻译文本
    private func readSiriTranslateText() {
        let key = "SiriTranslateText"
        var pendingText: String?

        // 优先从 App Group 读取
        if let shared = UserDefaults(suiteName: "group.com.alexzhang.VTM") {
            pendingText = shared.string(forKey: key)
            if pendingText != nil { shared.removeObject(forKey: key) }
        }

        // 备用：标准 UserDefaults
        if pendingText == nil {
            pendingText = UserDefaults.standard.string(forKey: key)
            if pendingText != nil { UserDefaults.standard.removeObject(forKey: key) }
        }

        guard let text = pendingText, !text.isEmpty else { return }

        VTMLog.app("📲 Siri 传入文本: \(text.prefix(50))...")
        sourceText = text

        // 自动触发翻译
        translator.translate(text: text) { result in
            switch result {
            case .success(let translated):
                self.translatedText = translated
                if !translated.isEmpty {
                    TranslationHistoryManager.shared.addRecord(
                        sourceText: text,
                        translatedText: translated,
                        sourceLanguage: self.translator.sourceLanguage,
                        targetLanguage: self.translator.targetLanguage
                    )
                }
                if self.autoPlay && !translated.isEmpty {
                    let lang = self.translator.targetLanguage == "zh" ? "zh-CN" : "en-US"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.ttsManager.speak(text: translated, language: lang)
                    }
                }
            case .failure(let error):
                self.showTopErrorMessage("翻译失败: \(error.localizedDescription)")
            }
        }
    }

    /// 自动恢复：如果 Whisper 模型因内存警告被卸载，且模型文件还在磁盘上 → 静默重新加载
    private func recoverWhisperIfNeeded() {
        guard !speechRecognizer.isModelLoaded else { return }
        // 检查是否有已下载的模型文件（可以恢复）
        guard !WhisperModel.downloadedModels().isEmpty else { return }
        print("🔄 TranslationView.onAppear — Whisper 已卸载但模型文件存在，自动恢复...")
        Task {
            await speechRecognizer.loadDefaultModel()
            print("🔄 Whisper 恢复结果: \(speechRecognizer.isModelLoaded ? "✅ 成功" : "❌ 失败")")
        }
    }

    private func startRecording() {
        CrashDiagnostics.log("TV.startRecording: ENTERED")
        guard !speechRecognizer.isRecording else { return }

        // 🔑 检查麦克风权限
        let micPermission = AVAudioSession.sharedInstance().recordPermission
        switch micPermission {
        case .undetermined:
            // 首次请求权限
            AVAudioSession.sharedInstance().requestRecordPermission { [self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startRecording()
                    } else {
                        self.showMicDeniedAlert = true
                        self.isPressing = false
                    }
                }
            }
            return
        case .denied:
            showMicDeniedAlert = true
            isPressing = false
            return
        case .granted:
            break
        @unknown default:
            break
        }

        // 🔑 如果 NLLB 导致 Whisper 被卸载了 → 重新加载
        CrashDiagnostics.log("TV.startRecording: check isModelLoaded=\(speechRecognizer.isModelLoaded)")
        CrashDiagnostics.logMemory(tag: "startRecording.afterGuard")
        if !speechRecognizer.isModelLoaded {
            CrashDiagnostics.log("TV.startRecording: model NOT loaded, entering reload path")
            guard !WhisperModel.downloadedModels().isEmpty else {
                showTopErrorMessage("语音识别模型未下载")
                isPressing = false
                return
            }

            // 通知 NLLB 卸载释放内存
            NotificationCenter.default.post(
                name: NSNotification.Name("WhisperWillLoad"), object: nil
            )

            isReloadingWhisper = true
            Task {
                await speechRecognizer.loadDefaultModel()
                await MainActor.run {
                    isReloadingWhisper = false
                    if speechRecognizer.isModelLoaded {
                        VTMLog.app("✅ Whisper 重新加载成功，继续录音")
                        // 重试录音
                        doOrShowError {
                            try speechRecognizer.startRecording(language: autoDetectLanguage ? nil : translator.sourceLanguage)
                            sourceText = ""
                            translatedText = ""
                            isTranscribing = false
                        }
                    } else {
                        showTopErrorMessage("Whisper 加载失败，请重试")
                        isPressing = false
                    }
                }
            }
            return
        }

        CrashDiagnostics.log("TV.startRecording: model IS loaded, normal path")

        sourceText = ""
        translatedText = ""
        isTranscribing = false

        CrashDiagnostics.log("TV.startRecording: calling sr.startRecording(language:)")
        do {
            try speechRecognizer.startRecording(language: autoDetectLanguage ? nil : translator.sourceLanguage)
            CrashDiagnostics.log("TV.startRecording: sr.startRecording SUCCESS ✓")
        } catch {
            CrashDiagnostics.log("TV.startRecording: sr.startRecording threw error: \(error.localizedDescription)")
            showTopErrorMessage("录音启动失败: \(error.localizedDescription)")
            isPressing = false
        }
    }

    /// 简化错误处理
    private func doOrShowError(_ block: () throws -> Void) {
        do { try block() }
        catch {
            showTopErrorMessage("错误: \(error.localizedDescription)")
            isPressing = false
        }
    }

    private func stopRecordingAndTranslate() {
        guard speechRecognizer.isRecording else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        Task {
            let text = await speechRecognizer.stopRecording()
            await MainActor.run {
                self.sourceText = text
                self.isTranscribing = false
            }

            guard !text.isEmpty else {
                // 空结果 — 提示用户录音太短或未检测到语音
                print("⚠️ 转录为空或空白，跳过翻译")
                let noVoiceMessage = AppStrings.shared.get("未检测到语音，请长按说话")
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.sourceText = noVoiceMessage
                }
                // 2 秒后恢复占位文字
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.sourceText == noVoiceMessage {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.sourceText = ""
                        }
                    }
                }
                return
            }

            // 🔍 自动检测源语言（如果启用）
            if self.autoDetectLanguage {
                if let detected = LanguageDetector.detectSourceLanguage(
                    text: text,
                    currentLanguage: self.translator.sourceLanguage
                ) {
                    VTMLog.app("🔍 自动切换源语言: \(self.translator.sourceLanguage) → \(detected)")
                    self.translator.setLanguages(source: detected, target: self.translator.targetLanguage)
                    // 检测成功 → 关闭自动模式，显示检测到的语言名
                    self.autoDetectLanguage = false
                }
            }

            self.translator.translate(text: text) { result in
                switch result {
                case .success(let translated):
                    self.translatedText = translated

                    // 📝 保存翻译历史（本地 UserDefaults，最多 50 条）
                    if !translated.isEmpty {
                        TranslationHistoryManager.shared.addRecord(
                            sourceText: text,
                            translatedText: translated,
                            sourceLanguage: self.translator.sourceLanguage,
                            targetLanguage: self.translator.targetLanguage
                        )
                    }

                    if self.autoPlay && !translated.isEmpty {
                        let lang = self.translator.targetLanguage == "zh" ? "zh-CN" : "en-US"
                        // 等 TTS 配置好音频会话后再播放（避免与录音清理竞争）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.ttsManager.speak(text: translated, language: lang)
                        }
                    }

                    // 🔑 NLLB 翻译后 Whisper 可能被卸载了 → 后台静默重载
                    if !self.translator.isUsingMLKit && !self.speechRecognizer.isModelLoaded {
                        print("🔄 NLLB 翻译完成，后台重载 Whisper...")
                        Task {
                            await self.speechRecognizer.loadDefaultModel()
                            print("🔄 Whisper 后台重载: \(self.speechRecognizer.isModelLoaded ? "✅" : "❌")")
                        }
                    }

                    // 🔄 对话模式：自动切换翻译方向
                    if self.conversationMode {
                        self.conversationDirectionIsAToB.toggle()
                        let newSource = self.conversationDirectionIsAToB
                            ? UserDefaults.standard.string(forKey: "conversationSourceLang") ?? self.translator.sourceLanguage
                            : self.translator.targetLanguage
                        let newTarget = self.conversationDirectionIsAToB
                            ? self.translator.targetLanguage
                            : UserDefaults.standard.string(forKey: "conversationSourceLang") ?? self.translator.sourceLanguage
                        self.translator.setLanguages(source: newSource, target: newTarget)
                    }

                case .failure(let error):
                    self.showTopErrorMessage("翻译失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - AnimatedDots 组件

/// 三点动画加载指示器 — "识别中..."
struct AnimatedDots: View {
    @ObservedObject private var strings = AppStrings.shared
    @State private var dotCount = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(String(repeating: ".", count: (dotCount % 3) + 1))
            .font(.caption2)
            .foregroundColor(.orange)
            .monospacedDigit()
            .onReceive(timer) { _ in
                dotCount += 1
            }
    }
}

// MARK: - LanguagePickerView 行内语言选择器

/// 语言选择 Sheet — 15 种常用语言 + 自动检测（仅在源语言选择器）
struct LanguagePickerView: View {
    @ObservedObject private var strings = AppStrings.shared
    let title: String
    let currentLanguage: String
    let onSelect: (String) -> Void
    let isSourcePicker: Bool

    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoDetectLanguage") private var autoDetectLanguage = true

    // 15 种常用语言
    private let languages: [(name: String, code: String)] = [
        ("中文", "zh"),
        ("English", "en"),
        ("日本語", "ja"),
        ("한국어", "ko"),
        ("Español", "es"),
        ("Français", "fr"),
        ("Deutsch", "de"),
        ("Português", "pt"),
        ("Русский", "ru"),
        ("العربية", "ar"),
        ("Italiano", "it"),
        ("Nederlands", "nl"),
        ("Polski", "pl"),
        ("Türkçe", "tr"),
        ("ไทย", "th"),
    ]

    var body: some View {
        NavigationStack {
            List {
                // 自动检测（仅源语言选择器）
                if isSourcePicker {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        autoDetectLanguage = true
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text(L10n: "自动")
                                .foregroundColor(.primary)
                            Spacer()
                            if autoDetectLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                ForEach(languages, id: \.code) { lang in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        autoDetectLanguage = false
                        onSelect(lang.code)
                        dismiss()
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(lang.name))
                                .foregroundColor(.primary)
                            Spacer()
                            if !autoDetectLanguage && lang.code == currentLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - RippleCircle 波纹动画组件

/// 单个波纹扩散圆环 — 从中心向外扩散并逐渐淡出
/// 用于麦克风按住时的涟漪动画效果
struct RippleCircle: View {
    @ObservedObject private var strings = AppStrings.shared
    let color: Color
    let delay: Double
    @Binding var isPressing: Bool

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.5

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 2)
            .frame(width: 82, height: 82)
            .scaleEffect(scale)
            .opacity(isPressing ? 1 : 0)
            .onAppear {
                animate()
            }
            .onChange(of: isPressing) { _, newValue in
                if newValue {
                    animate()
                } else {
                    // 松手时快速淡出
                    withAnimation(.easeOut(duration: 0.15)) {
                        scale = 0.6
                        opacity = 0
                    }
                }
            }
    }

    private func animate() {
        // 循环动画：扩散 + 淡出 → 重置 → 重复
        withAnimation(
            .easeOut(duration: 0.9)
            .delay(delay)
        ) {
            scale = 1.6
            opacity = 0
        }

        // 动画结束后重置，实现循环
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.9) {
            guard isPressing else { return }
            scale = 0.6
            opacity = 0.5
            animate()
        }
    }
}

#Preview {
    TranslationView()
        .environmentObject(SpeechRecognizer())
        .environmentObject(Translator())
        .environmentObject(TTSManager())
}
