//
//  APIConfig.swift
//  VTM
//
//  纯本地离线方案 — 不调用任何外部 API
//  翻译: NLLB-200 ONNX（本地离线）
//  语音识别: Whisper.cpp (本地模型)
//  TTS: Apple AVSpeechSynthesizer
//

import Foundation

struct APIConfig {
    // VTM 采用全本地方案，暂不配置任何外部 API
    
    // 如需后续接入云端翻译，可在此添加：
    // static let translationAPIKey = "YOUR_KEY"
    // static let translationEndpoint = "https://..."
}
