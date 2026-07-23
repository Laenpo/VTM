//
//  WhisperModelDownloadView.swift
//  VTM
//
//  Whisper 模型下载按钮 + 进度条
//

import SwiftUI

struct WhisperModelDownloadButton: View {
    @ObservedObject private var strings = AppStrings.shared
    let model: WhisperModel
    let onLoaded: ((WhisperModel) -> Void)?
    
    @State private var downloadStatus: DownloadStatus = .notDownloaded
    @State private var downloadProgress: Double = 0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var observation: NSKeyValueObservation?
    @State private var showDeleteConfirm = false
    
    enum DownloadStatus: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case error(String)
    }
    
    init(model: WhisperModel, onLoaded: ((WhisperModel) -> Void)? = nil) {
        self.model = model
        self.onLoaded = onLoaded
        _downloadStatus = State(initialValue: model.fileExists() ? .downloaded : .notDownloaded)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if case .downloading = downloadStatus {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                if case .error(let message) = downloadStatus {
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button(action: handleTap) {
                Group {
                    switch downloadStatus {
                    case .notDownloaded:
                        Label(L10n: "下载", systemImage: "icloud.and.arrow.down")
                            .font(.caption)
                    case .downloading:
                        Label(L10n: "取消", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    case .downloaded:
                        Label(L10n: "已下载", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    case .error:
                        Label(L10n: "重试", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(downloadStatus == .downloaded ? .green : .blue)
            .disabled(downloadStatus == .downloaded)
        }
        .padding(.vertical, 4)
        .contextMenu {
            if case .downloaded = downloadStatus {
                Button(role: .destructive, action: deleteModel) {
                    Label(L10n: "删除模型", systemImage: "trash")
                }
            }
        }
        .onDisappear {
            downloadTask?.cancel()
        }
    }
    
    private func handleTap() {
        switch downloadStatus {
        case .notDownloaded, .error:
            startDownload()
        case .downloading:
            cancelDownload()
        case .downloaded:
            onLoaded?(model)
        }
    }
    
    private func startDownload() {
        downloadStatus = .downloading
        downloadProgress = 0
        
        guard let url = URL(string: model.url) else {
            downloadStatus = .error("无效的下载地址")
            return
        }
        
        downloadTask = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.downloadStatus = .error(error.localizedDescription)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.downloadStatus = .error("服务器错误")
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.downloadStatus = .error("下载失败")
                }
                return
            }
            
            do {
                // 确保 Documents 目录存在
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                if !FileManager.default.fileExists(atPath: documentsDir.path) {
                    try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
                }
                
                // 如果目标文件已存在则先删除
                if FileManager.default.fileExists(atPath: self.model.fileURL.path) {
                    try FileManager.default.removeItem(at: self.model.fileURL)
                }
                
                try FileManager.default.copyItem(at: tempURL, to: self.model.fileURL)
                
                DispatchQueue.main.async {
                    self.downloadStatus = .downloaded
                    self.onLoaded?(self.model)
                    // 通知 ContentView 自动加载模型
                    NotificationCenter.default.post(name: NSNotification.Name("ModelDownloaded"), object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.downloadStatus = .error("保存失败: \(error.localizedDescription)")
                }
            }
        }
        
        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.downloadProgress = progress.fractionCompleted
            }
        }
        
        downloadTask?.resume()
    }
    
    private func cancelDownload() {
        downloadTask?.cancel()
        downloadStatus = .notDownloaded
        downloadProgress = 0
    }
    
    private func deleteModel() {
        do {
            if FileManager.default.fileExists(atPath: model.fileURL.path) {
                try FileManager.default.removeItem(at: model.fileURL)
            }
            downloadStatus = .notDownloaded
            downloadProgress = 0
        } catch {
            downloadStatus = .error("删除失败: \(error.localizedDescription)")
        }
    }
}
