//
//  NLModel.swift
//  VTM
//
//  NLLB-200 ONNX 翻译模型定义 — 可选高级翻译引擎
//  - 一个模型: distilled 600M (量化版 ~940 MB)
//  - Encoder + Decoder + Tokenizer + SentencePiece 四文件
//

import Foundation

// MARK: - Model File Descriptor

/// 单个模型文件描述
struct NLModelFile: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let filename: String
    let fileSize: Int64

    var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func exists() -> Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    var formattedSize: String {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: fileSize)
    }
}

// MARK: - NLModel

struct NLModel: Identifiable {
    let id = UUID()
    let name: String
    let info: String
    let supportedPairs: String
    let files: [NLModelFile]

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.fileSize }
    }

    var formattedTotalSize: String {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: totalSize)
    }

    var isFullyDownloaded: Bool {
        files.allSatisfy { $0.exists() }
    }

    var downloadedCount: Int {
        files.filter { $0.exists() }.count
    }

    var encoderPath: URL? {
        files.first { $0.filename.contains("encoder") }?.localURL
    }

    var decoderPath: URL? {
        files.first { $0.filename.contains("decoder") }?.localURL
    }

    var tokenizerPath: URL? {
        files.first { $0.filename.contains("tokenizer.json") }?.localURL
    }

    var sentencePiecePath: URL? {
        files.first { $0.filename.contains("sentencepiece") }?.localURL
    }

    // MARK: - 唯一模型

    /// NLLB-200 蒸馏 600M (量化版)
    /// 来源: Xenova/nllb-200-distilled-600M (Apache 2.0)
    /// 总计 ~940 MB — 可选下载，默认可使用 Apple Translation
    static let distilled600M = NLModel(
        name: "nllb-200-distilled-600M",
        info: "600M 参数 · ~940 MB · 200 语言",
        supportedPairs: "200 种语言互译（含中英日韩法德俄阿等）",
        files: [
            NLModelFile(
                name: "Encoder (量化版)",
                url: "https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/onnx/encoder_model_quantized.onnx",
                filename: "nllb-600M_encoder_quantized.onnx",
                fileSize: 419 * 1024 * 1024
            ),
            NLModelFile(
                name: "Decoder (量化版)",
                url: "https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/onnx/decoder_model_merged_quantized.onnx",
                filename: "nllb-600M_decoder_quantized.onnx",
                fileSize: 476 * 1024 * 1024
            ),
            NLModelFile(
                name: "Tokenizer",
                url: "https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/tokenizer.json",
                filename: "nllb-600M_tokenizer.json",
                fileSize: 18 * 1024 * 1024
            ),
            NLModelFile(
                name: "SentencePiece 模型",
                url: "https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/sentencepiece.bpe.model",
                filename: "nllb-600M_sentencepiece.bpe.model",
                fileSize: 5 * 1024 * 1024
            ),
        ]
    )
}
