//
//  WhisperModel.swift
//  VTM
//
//  Whisper 模型定义 — 从 huggingface 下载 ggml 模型文件
//  统一使用 small 模型（与 Android 对齐，高精度）
//

import Foundation

struct WhisperModel: Identifiable {
    let id = UUID()
    let name: String
    let info: String
    let url: String
    let filename: String

    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    var fileSize: Int64? {
        guard fileExists() else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int64
    }

    var formattedSize: String {
        guard let size = fileSize else { return "未下载" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - 预置模型（仅 small，高精度，466 MB）

    static let availableModels: [WhisperModel] = [
        WhisperModel(
            name: "small",
            info: "F16 · 466 MB — 高精度语音识别",
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            filename: "ggml-small.bin"
        ),
    ]

    // MARK: - 工具方法

    static func downloadedModels() -> [WhisperModel] {
        availableModels.filter { $0.fileExists() }
    }

    /// 获取已下载模型（仅有 small）
    static func recommendedModel() -> WhisperModel? {
        return downloadedModels().first
    }
}
