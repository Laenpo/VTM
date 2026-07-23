//
//  CrashDiagnostics.swift
//  VTM
//
//  文件级 crash 诊断日志
//  ⚠️ 使用 C 标准库 fwrite + fflush 确保 crash 前立即落盘
//  ⚠️ 同时写 NSLog（系统日志，App 崩溃后仍可通过 Console.app 查看）
//  每次启动时读取上次 crash 日志并打印到控制台
//

import Foundation
import os

enum CrashDiagnostics {
    // C 文件指针 — fopen/fwrite/fflush 是最可靠的 crash 前写盘方式
    private static var fileHandle: UnsafeMutablePointer<FILE>?

    private static let logFile: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vtm_crash_diag.log")
    }()

    private static var lastLogLine = ""
    private static let lock = NSLock()

    // MARK: - 启动时

    /// 启动时调用 — 读取上次 crash 日志并打印
    static func reportLastCrash() {
        guard let content = try? String(contentsOf: logFile, encoding: .utf8),
              !content.isEmpty else {
            print("📋 [CrashDiag] 无上次 crash 日志")
            return
        }
        print("📋 [CrashDiag] ====== 上次 crash 诊断日志 ======")
        print(content)
        print("📋 [CrashDiag] ====== 日志结束 ======")

        // 清空日志，准备本次记录
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
    }

    // MARK: - 同步写日志（crash 前一定落盘）

    /// 记录一个诊断点
    /// ⚠️ 三重保障：NSLog → C fwrite+fflush → 内存 lastLogLine 兜底
    /// ⚠️ 同步执行，阻塞调用者直到写入完成
    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: now)

        let line = "[\(timestamp)] \(message)"

        // 保留最后一行到内存（可通过 lldb/gdb 读取）
        lastLogLine = line

        // 1️⃣ NSLog — 写入系统日志（App 崩溃后仍可查看）
        os_log(.default, "%{public}@", line)

        // 2️⃣ C fwrite + fflush — 直接写文件（最可靠的 crash 前写盘方式）
        let cLine = line + "\n"
        cLine.withCString { ptr in
            if fileHandle == nil {
                fileHandle = fopen(logFile.path, "a")
            }
            if let fh = fileHandle {
                fwrite(ptr, 1, strlen(ptr), fh)
                fflush(fh)  // ⚠️ 关键：强制刷到磁盘
            }
        }
    }

    /// 安全关闭文件（App 进入后台或终止时调用）
    static func closeFile() {
        lock.lock()
        defer { lock.unlock() }
        if let fh = fileHandle {
            fclose(fh)
            fileHandle = nil
        }
    }

    /// 获取已知的最后一条日志行（崩溃后可用 lldb 读取）
    static var lastLine: String { lastLogLine }

    // MARK: - 内存诊断

    /// 记录当前进程物理内存占用
    static func logMemory(tag: String = "") {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let mb = Double(info.resident_size) / 1_048_576
            let prefix = tag.isEmpty ? "Memory" : "Memory.\(tag)"
            log(String(format: "%@: resident %.1f MB", prefix, mb))
        }
    }

    /// 获取当前进程物理内存 (MB)
    static func currentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1_048_576
    }
}
