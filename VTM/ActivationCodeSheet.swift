//
//  ActivationCodeSheet.swift
//  VTM
//
//  激活码输入 Sheet — XXXX-XXXX-XXXX 格式自动加连字符
//  支持粘贴自动清理、错误抖动反馈、激活成功庆祝
//

import SwiftUI

struct ActivationCodeSheet: View {
    @ObservedObject private var strings = AppStrings.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ActivationManager.shared

    @State private var rawInput: String = ""
    @State private var isValidating = false
    @State private var showError = false
    @State private var showSuccess = false
    @State private var errorShake: CGFloat = 0

    private let maxChars = 14 // 12 chars + 2 hyphens

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            showSuccess
                            ? Color.green.opacity(0.12)
                            : Color.blue.opacity(0.12)
                        )
                        .frame(width: 88, height: 88)

                    Image(systemName: showSuccess ? "checkmark.shield.fill" : "key.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            showSuccess ? Color.green : Color.blue
                        )
                }
                .scaleEffect(showSuccess ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showSuccess)

                // Title
                VStack(spacing: 6) {
                    Text(showSuccess ? "激活成功" : "输入激活码")
                        .font(.title2)
                        .fontWeight(.bold)

                    if !showSuccess {
                        Text(L10n: "请输入 12 位激活码以获取永久使用权")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text(L10n: "感谢您的支持！VTM 已永久激活。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Code Input (only when not succeeded)
                if !showSuccess {
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            TextField("XXXX-XXXX-XXXX", text: $rawInput)
                                .font(.system(size: 22, weight: .medium, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.center)
                                .keyboardType(.asciiCapable)
                                .onChange(of: rawInput) { _, newValue in
                                    rawInput = formatCode(newValue)
                                    if showError { showError = false }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(showError ? Color.red : Color.clear, lineWidth: 1.5)
                                )
                                .offset(x: errorShake)
                        }

                        // Error message
                        if showError {
                            Text(L10n: "激活码无效")
                                .font(.caption)
                                .foregroundColor(.red)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                }

                // Action Button
                Button {
                    if showSuccess {
                        dismiss()
                    } else {
                        validateAndActivate()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text(showSuccess ? "完成" : (isValidating ? "验证中..." : "激活"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        canSubmit
                        ? (showSuccess ? Color.green : Color.blue)
                        : Color.gray.opacity(0.4)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit && !showSuccess)

                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Computed

    private var canSubmit: Bool {
        let cleaned = rawInput
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return cleaned.count == 12 && !isValidating
    }

    // MARK: - Formatting

    /// 自动插入连字符：XXXX-XXXX-XXXX
    private func formatCode(_ input: String) -> String {
        // 去除所有连字符和空格
        var cleaned = input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        // 限制最多 12 字符
        if cleaned.count > 12 {
            cleaned = String(cleaned.prefix(12))
        }

        // 只允许合法字符
        let allowed = CharacterSet(charactersIn: "23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        cleaned = String(cleaned.filter { $0.unicodeScalars.allSatisfy { allowed.contains($0) } })

        // 插入连字符
        var result = ""
        for (i, ch) in cleaned.enumerated() {
            if i == 4 || i == 8 {
                result.append("-")
            }
            result.append(ch)
        }

        return result
    }

    // MARK: - Validate & Activate

    private func validateAndActivate() {
        guard canSubmit else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        isValidating = true

        // 短暂延迟模拟验证（SHA-256 极快，加延迟让用户感知验证中）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let success = manager.activate(rawInput)

            withAnimation(.easeInOut(duration: 0.25)) {
                isValidating = false
                if success {
                    showSuccess = true
                    let notifGen = UINotificationFeedbackGenerator()
                    notifGen.notificationOccurred(.success)
                } else {
                    showError = true
                    shakeField()
                    let errorGen = UINotificationFeedbackGenerator()
                    errorGen.notificationOccurred(.error)
                }
            }
        }
    }

    /// 错误抖动动画
    private func shakeField() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
            errorShake = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                errorShake = -6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                errorShake = 0
            }
        }
    }
}

#Preview {
    ActivationCodeSheet()
}
