//
//  ModelManagementView.swift
//  VTM
//
//  模型管理页面：统一三引擎面板
//  - Whisper: 离线语音识别（必需）
//  - ML Kit: Google 设备端翻译（主力）
//  - NLLB-200: ONNX 离线翻译（后备）
//  WiFi-only 下载检查
//

import SwiftUI
import Network

struct ModelManagementView: View {
    @ObservedObject private var strings = AppStrings.shared
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    @EnvironmentObject var translator: Translator

    @State private var isOnWiFi = true
    @State private var showCellularWarning = false
    @State private var showClearConfirm = false

    /// "i" 信息弹窗
    @State private var infoModelType: InfoModelType?

    enum InfoModelType: Identifiable {
        case whisper, mlKit, nllb

        var id: String {
            switch self {
            case .whisper: return "whisper"
            case .mlKit: return "mlkit"
            case .nllb: return "nllb"
            }
        }
    }

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - 1. Whisper 语音识别
                modelCard(
                    icon: "waveform.circle.fill",
                    color: .blue,
                    title: "Whisper",
                    subtitle: "离线语音识别引擎",
                    status: whisperStatus,
                    sizeMB: "~466 MB",
                    infoType: .whisper
                ) {
                    ForEach(WhisperModel.availableModels) { model in
                        WhisperModelDownloadButton(model: model) { loadedModel in
                            print("✅ Whisper 模型已就绪: \(loadedModel.name)")
                        }
                    }
                }

                // MARK: - 2. ML Kit 翻译
                modelCard(
                    icon: "sparkles",
                    color: .purple,
                    title: "ML Kit",
                    subtitle: "主力翻译引擎 · Google 设备端",
                    status: mlKitStatus,
                    sizeMB: "~30 MB / 语言对",
                    infoType: .mlKit
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: mlKitStatus.isReady ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(mlKitStatus.isReady ? .green : .secondary)
                                .font(.caption)
                            Text(L10n: "zh ↔ en 模型")
                                .font(.caption)
                            Spacer()
                            if translator.isMLKitDownloading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }

                        if !mlKitStatus.isReady && !translator.isMLKitDownloading {
                            Button {
                                translator.prewarmMLKit()
                            } label: {
                                Label(L10n: "预下载 zh↔en 模型", systemImage: "arrow.down.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // MARK: - 3. NLLB-200 翻译
                modelCard(
                    icon: "globe.asia.australia.fill",
                    color: .orange,
                    title: "NLLB-200",
                    subtitle: "200 语言离线翻译后备引擎",
                    status: nllbStatus,
                    sizeMB: "~940 MB",
                    infoType: .nllb
                ) {
                    ForEach([NLModel.distilled600M]) { model in
                        NLModelDownloadButton(model: model)
                    }
                }

                // MARK: - WiFi 状态
                wifiStatusBanner

                // MARK: - 清除缓存
                clearCacheSection
            }
            .padding()
        }
        .navigationTitle(Text(L10n: "模型管理"))
        .navigationBarTitleDisplayMode(.large)
        .alert(AppStrings.shared.get("蜂窝网络提醒"), isPresented: $showCellularWarning) {
            Button(AppStrings.shared.get("仍然下载")) { showCellularWarning = false }
            Button(AppStrings.shared.get("取消"), role: .cancel) { }
        } message: {
            Text(L10n: "当前使用蜂窝网络，下载大模型可能消耗大量流量。建议连接 Wi-Fi 后再下载。")
        }
        .alert(AppStrings.shared.get("清除缓存"), isPresented: $showClearConfirm) {
            Button(AppStrings.shared.get("取消"), role: .cancel) { }
            Button(AppStrings.shared.get("确认清除"), role: .destructive) { clearAllModels() }
        } message: {
            Text(L10n: "将删除所有已下载的模型文件，需要重新下载才能使用。确定继续吗？")
        }
        .sheet(item: $infoModelType) { type in
            modelInfoSheet(type)
        }
        .onAppear { startNetworkMonitoring() }
        .onDisappear { monitor.cancel() }
    }

    // MARK: - Model Status

    private var whisperStatus: ModelStatus {
        if speechRecognizer.isModelLoaded {
            return .loaded
        } else if WhisperModel.downloadedModels().isEmpty {
            return .notDownloaded
        } else {
            return .downloaded
        }
    }

    private var mlKitStatus: ModelStatus {
        if translator.isMLKitDownloading {
            return .downloading
        } else if translator.isMLKitReady {
            return .loaded
        } else {
            return .notDownloaded
        }
    }

    private var nllbStatus: ModelStatus {
        if translator.isNLLBLoading {
            return .downloading
        } else if translator.isNLLBReady {
            return .loaded
        } else if translator.isNLLBDownloaded {
            return .downloaded
        } else {
            return .notDownloaded
        }
    }

    // MARK: - Model Card

    @ViewBuilder
    private func modelCard(
        icon: String,
        color: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        status: ModelStatus,
        sizeMB: String? = nil,
        infoType: InfoModelType,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.headline)
                            statusBadge(status)
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let size = sizeMB {
                            Text(verbatim: size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // ⓘ 信息按钮
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    infoModelType = infoType
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            content()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: ModelStatus) -> some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - Info Sheet

    @ViewBuilder
    private func modelInfoSheet(_ type: InfoModelType) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch type {
                    case .whisper:
                        infoSection(
                            icon: "waveform.circle.fill",
                            color: .blue,
                            title: "Whisper.cpp",
                            description: "OpenAI 开源的高精度语音识别模型，由 ggerganov/whisper.cpp 移植到 C/C++。",
                            details: [
                                ("模型", "small (F16)"),
                                ("大小", "~466 MB"),
                                ("精度", "高精度，适合真实场景"),
                                ("语言", "多语言自动检测"),
                                ("协议", "MIT 开源"),
                                ("推理", "完全本地离线，无需网络"),
                            ]
                        )
                    case .mlKit:
                        infoSection(
                            icon: "sparkles",
                            color: .purple,
                            title: "Google ML Kit Translate",
                            description: "Google 设备端翻译 SDK，利用设备算力进行本地翻译，速度极快且隐私安全。",
                            details: [
                                ("类型", "设备端神经网络翻译"),
                                ("大小", "~30 MB / 语言对"),
                                ("速度", "极快（设备端推理）"),
                                ("支持", "60+ 语言，含中英日韩等"),
                                ("主力", "VTM 默认翻译引擎"),
                                ("策略", "首次使用前自动下载"),
                            ]
                        )
                    case .nllb:
                        infoSection(
                            icon: "globe.asia.australia.fill",
                            color: .orange,
                            title: "NLLB-200 (No Language Left Behind)",
                            description: "Meta AI 的多语言翻译模型，支持 200 种语言。VTM 使用 ONNX Runtime 进行设备端推理。",
                            details: [
                                ("模型", "distilled-600M (INT8 量化)"),
                                ("大小", "~940 MB（4个文件）"),
                                ("范围", "200 种语言间互译"),
                                ("速度", "较慢（CPU 推理，短句 ~3-10s）"),
                                ("角色", "后备引擎，仅 ML Kit 不支持时使用"),
                                ("加载", "按需懒加载，不常驻内存"),
                            ]
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(type == .whisper ? "Whisper 详情" : (type == .mlKit ? "ML Kit 详情" : "NLLB-200 详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { infoModelType = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func infoSection(
        icon: String,
        color: Color,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        details: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(color)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            ForEach(details, id: \.0) { key, value in
                HStack(alignment: .top) {
                    Text(LocalizedStringKey(key))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 65, alignment: .leading)
                    Text(LocalizedStringKey(value))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - WiFi Status

    private var wifiStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: isOnWiFi ? "wifi" : "antenna.radiowaves.left.and.right")
                .foregroundColor(isOnWiFi ? .green : .orange)
            if isOnWiFi {
                Text(L10n: "已连接 Wi-Fi — 可放心下载")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(L10n: "使用蜂窝网络 — 下载将消耗流量")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOnWiFi ? Color.adaptiveGreenMedium : Color.adaptiveOrangeTranslucent)
        .cornerRadius(10)
    }

    // MARK: - Clear Cache

    private var clearCacheSection: some View {
        Button(action: {
            showClearConfirm = true
        }) {
            HStack {
                Image(systemName: "trash")
                Text(L10n: "清除所有模型缓存")
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func clearAllModels() {
        for model in WhisperModel.availableModels where model.fileExists() {
            try? FileManager.default.removeItem(at: model.fileURL)
        }
        for model in [NLModel.distilled600M] {
            for file in model.files where file.exists() {
                try? FileManager.default.removeItem(at: file.localURL)
            }
        }
        print("🗑️ 所有模型缓存已清除")
    }

    // MARK: - Network Monitor

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isOnWiFi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

// MARK: - ModelStatus Enum

enum ModelStatus {
    case loaded
    case downloaded
    case downloading
    case notDownloaded

    var label: LocalizedStringKey {
        switch self {
        case .loaded: return "已加载"
        case .downloaded: return "已下载"
        case .downloading: return "下载中"
        case .notDownloaded: return "未下载"
        }
    }

    var color: Color {
        switch self {
        case .loaded: return .green
        case .downloaded: return .blue
        case .downloading: return .orange
        case .notDownloaded: return .secondary
        }
    }

    var isReady: Bool {
        if case .loaded = self { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        ModelManagementView()
            .environmentObject(SpeechRecognizer())
            .environmentObject(Translator())
    }
}
