//
//  NLModelDownloadView.swift
//  VTM
//
//  NLLB-200 ONNX 模型下载视图
//  - 多文件并行展示 (Encoder / Decoder / Tokenizer / SentencePiece)
//  - 顺序下载 + 进度条
//  - 已下载状态管理
//

import SwiftUI

// MARK: - NLModelDownloadView

struct NLModelDownloadView: View {
    @ObservedObject private var strings = AppStrings.shared
    let model: NLModel

    @State private var fileStatuses: [UUID: FileDownloadStatus] = [:]
    @State private var currentDownloadIndex: Int = 0
    @State private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    @State private var observations: [UUID: NSKeyValueObservation] = [:]

    enum FileDownloadStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case error(String)
    }

    init(model: NLModel) {
        self.model = model
        var initial: [UUID: FileDownloadStatus] = [:]
        for file in model.files {
            initial[file.id] = file.exists() ? .downloaded : .notDownloaded
        }
        _fileStatuses = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(model.name))
                        .font(.headline)
                    Text(LocalizedStringKey(model.info))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("支持: ") + Text(LocalizedStringKey(model.supportedPairs))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                downloadButton
            }

            Divider()

            // 文件列表
            VStack(spacing: 6) {
                ForEach(model.files) { file in
                    fileRow(file)
                }
            }

            // 总进度
            if isDownloading {
                overallProgressView
            }

            // 错误信息
            if let error = firstError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.adaptiveCardBg)
        .cornerRadius(12)
        .onDisappear {
            cancelAllDownloads()
        }
    }

    // MARK: - File Row

    private func fileRow(_ file: NLModelFile) -> some View {
        HStack(spacing: 8) {
            // 状态图标
            statusIcon(for: file)

            // 文件名 + 大小
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(file.name))
                    .font(.caption)
                    .fontWeight(.medium)
                Text(file.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 进度条 (下载中)
            if case .downloading(let progress) = fileStatuses[file.id] {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 60)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .frame(width: 35, alignment: .trailing)
            }

            // 已下载标记
            if file.exists() && !isDownloading {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }

    private func statusIcon(for file: NLModelFile) -> some View {
        let status = fileStatuses[file.id] ?? .notDownloaded

        return Group {
            switch status {
            case .notDownloaded:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            case .downloaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }

    // MARK: - Download Button

    private var downloadButton: some View {
        Group {
            if isFullyDownloaded {
                Button(role: .destructive, action: deleteAllFiles) {
                    Label(L10n: "删除", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if isDownloading {
                Button(action: cancelAllDownloads) {
                    Label(L10n: "取消", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            } else {
                Button(action: startDownloadAll) {
                    Label(L10n: "下载全部", systemImage: "icloud.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
        }
    }

    // MARK: - Overall Progress

    private var overallProgressView: some View {
        VStack(alignment: .leading, spacing: 4) {
            let completed = Double(model.files.filter { $0.exists() || isFileDownloaded($0) }.count)
            let total = Double(model.files.count)
            let progress = completed / total

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())

            Text("正在下载 \(currentDownloadIndex + 1)/\(model.files.count)...")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Computed

    private var isDownloading: Bool {
        fileStatuses.values.contains { status in
            if case .downloading = status { return true }
            return false
        }
    }

    private var isFullyDownloaded: Bool {
        model.files.allSatisfy { $0.exists() }
    }

    private var firstError: String? {
        for status in fileStatuses.values {
            if case .error(let msg) = status { return msg }
        }
        return nil
    }

    private func isFileDownloaded(_ file: NLModelFile) -> Bool {
        if case .downloaded = fileStatuses[file.id] { return true }
        return file.exists()
    }

    // MARK: - Download Logic

    private func startDownloadAll() {
        guard !isDownloading else { return }
        currentDownloadIndex = 0
        downloadNext()
    }

    private func downloadNext() {
        guard currentDownloadIndex < model.files.count else {
            print("✅ 所有文件下载完成: \(model.name)")
            return
        }

        let file = model.files[currentDownloadIndex]

        // 跳过已存在的文件
        if file.exists() {
            fileStatuses[file.id] = .downloaded
            currentDownloadIndex += 1
            downloadNext()
            return
        }

        fileStatuses[file.id] = .downloading(progress: 0)

        guard let url = URL(string: file.url) else {
            fileStatuses[file.id] = .error("无效的下载地址")
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id] = .error(error.localizedDescription)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id] = .error("服务器错误")
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id] = .error("下载失败")
                }
                return
            }

            do {
                if FileManager.default.fileExists(atPath: file.localURL.path) {
                    try FileManager.default.removeItem(at: file.localURL)
                }
                try FileManager.default.copyItem(at: tempURL, to: file.localURL)

                DispatchQueue.main.async {
                    self.fileStatuses[file.id] = .downloaded
                    // 继续下载下一个
                    self.currentDownloadIndex += 1
                    self.downloadNext()
                }
            } catch {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id] = .error("保存失败: \(error.localizedDescription)")
                }
            }
        }

        // 监听进度
        let obs = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.fileStatuses[file.id] = .downloading(progress: progress.fractionCompleted)
            }
        }

        downloadTasks[file.id] = task
        observations[file.id] = obs
        task.resume()
    }

    private func cancelAllDownloads() {
        for (_, task) in downloadTasks {
            task.cancel()
        }
        downloadTasks.removeAll()
        observations.removeAll()

        for file in model.files {
            if case .downloading = fileStatuses[file.id] {
                fileStatuses[file.id] = .notDownloaded
            }
        }
    }

    private func deleteAllFiles() {
        for file in model.files {
            if file.exists() {
                try? FileManager.default.removeItem(at: file.localURL)
            }
            fileStatuses[file.id] = .notDownloaded
        }
    }
}

// MARK: - Preview

#Preview {
    NLModelDownloadView(model: NLModel.distilled600M)
        .padding()
}

// MARK: - NLModelDownloadButton (行内按钮, 用于 ModelManagementView)

/// NLLB 模型下载行按钮 — 显示模型名称/状态，支持多文件顺序下载
struct NLModelDownloadButton: View {
    @ObservedObject private var strings = AppStrings.shared
    let model: NLModel

    @State private var downloadStatus: DownloadStatus = .notDownloaded
    @State private var downloadProgress: Double = 0
    @State private var currentFileIndex: Int = 0

    enum DownloadStatus: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case error(String)
    }

    init(model: NLModel) {
        self.model = model
        _downloadStatus = State(initialValue: model.isFullyDownloaded ? .downloaded : .notDownloaded)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if case .downloading = downloadStatus {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                    Text(verbatim: "\(model.files[currentFileIndex].name) · \(Int(downloadProgress * 100))%")
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
                Button(role: .destructive, action: deleteAll) {
                    Label(L10n: "删除模型", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Actions

    private func handleTap() {
        switch downloadStatus {
        case .notDownloaded, .error:
            startDownload()
        case .downloading:
            cancelDownload()
        case .downloaded:
            break
        }
    }

    private func startDownload() {
        downloadStatus = .downloading
        downloadProgress = 0
        currentFileIndex = 0
        downloadNextFile()
    }

    private func downloadNextFile() {
        guard currentFileIndex < model.files.count else {
            downloadStatus = .downloaded
            downloadProgress = 1.0
            // 通知 ContentView 自动加载模型
            NotificationCenter.default.post(name: NSNotification.Name("ModelDownloaded"), object: nil)
            return
        }

        let file = model.files[currentFileIndex]
        if file.exists() {
            currentFileIndex += 1
            downloadProgress = Double(currentFileIndex) / Double(model.files.count)
            downloadNextFile()
            return
        }

        guard let url = URL(string: file.url) else {
            downloadStatus = .error("无效的下载地址: \(file.name)")
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
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
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                if !FileManager.default.fileExists(atPath: documentsDir.path) {
                    try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
                }
                if FileManager.default.fileExists(atPath: file.localURL.path) {
                    try FileManager.default.removeItem(at: file.localURL)
                }
                try FileManager.default.copyItem(at: tempURL, to: file.localURL)

                DispatchQueue.main.async {
                    self.currentFileIndex += 1
                    self.downloadProgress = Double(self.currentFileIndex) / Double(self.model.files.count)
                    self.downloadNextFile()
                }
            } catch {
                DispatchQueue.main.async {
                    self.downloadStatus = .error("保存失败: \(error.localizedDescription)")
                }
            }
        }

        task.resume()
    }

    private func cancelDownload() {
        URLSession.shared.invalidateAndCancel()
        downloadStatus = .notDownloaded
        downloadProgress = 0
    }

    private func deleteAll() {
        for file in model.files where file.exists() {
            try? FileManager.default.removeItem(at: file.localURL)
        }
        downloadStatus = .notDownloaded
        downloadProgress = 0
    }
}
