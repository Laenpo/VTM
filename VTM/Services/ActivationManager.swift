//
//  ActivationManager.swift
//  VTM
//
//  试用期管理 + 离线激活码验证
//  - 7 天免费试用，从首次启动算起
//  - SHA-256 哈希验证激活码（离线，无需服务器）
//  - Keychain 持久化激活状态
//

import Foundation
import Security
import CommonCrypto
import Combine

final class ActivationManager: ObservableObject {
    static let shared = ActivationManager()

    // MARK: - Published State

    @Published var isActivated: Bool = false
    @Published var trialDaysRemaining: Int = 7
    @Published var trialStartDate: Date?

    // MARK: - Trial Duration

    static let trialDays: Int = 7
    private static let trialStartKey = "com.vtm.firstLaunchDate"
    private static let activationKeychainKey = "com.vtm.activation"

    // ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    //  ACTIVATION CODE VALIDATION
    //  50 pre-generated SHA-256 hashes. Codes are NOT in the binary.
    //  Generating new codes: run with ALEAD activation hash generator.
    // ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

    private let validHashes: Set<String> = [
        "808718dfb4232869940fb21755e56122999a3462f2918f1cbaef5c2986539a2c",
        "debe11838eac0856706b1add9fe7450f177e3689e855e5ee37c2b690360a0a13",
        "bdba12932b10ab59c9031f4c4482457df7181eb0d593745078c154a5728c7188",
        "d4d2e79c219e6079c6dd08a1481274a87b4b7ec64ba1f5cd27630d2178f16712",
        "2e659f3b0b0551ebea08822375227c0afecd179aa2503791fab9ca8bfebf4ae8",
        "c5835967a2426505090003941c12375905a326e3463c0dfe68995d83f7fcb9ff",
        "444e6893a2de0f03af6c763d2e255b63dbe50f39b4aad4551138233b2f525756",
        "9fd0e687f4d3c011fd7e95dc683542f47630e80d55dc74fee803b7308911dff2",
        "847eec1b92e3d82d8f682cdb5393a554c6db08186492f1876ff3663485d38123",
        "a550014b0d785f5781e8f4a2736332b643d625a9080c04d73abb81ef9ca4d668",
        "611b4a94589d8d14e768d93b6d991a1276bcc754949becbc176164864b199d60",
        "3fcaf5fd4e59d5e52a49e7c654a94cb4092ebc4df726b15fd1686e1030217996",
        "9b121ea579ae35fc39f75571680f3ee2583bfc9de4a33b2174edf566b385943d",
        "fdaf31d03f75ce050d0aef42549660dd127813420afbea0f2d08f4acad6c6197",
        "c94621c459063329f351aad8919fc912a5786eae07c6bacf03c4dda5134795c4",
        "23a9d3b7b4006f46b19f12ba939e9366e764c55b0cd1bbc888049806258bc72c",
        "5f8fb7a64b8aad42f52878b7090ddf40e688a160b95885304fa5afd7cdfb4b39",
        "8db253e2fa1c50b0569cddeb804482ef68c973e140a238ce54898dd33542fc78",
        "7d10751a50fa8ce92aa8f6e09302c5a11cec9cb7f8db0454a805c71e6f1a3cff",
        "bc89d500e41325e03adc731975ca9e679f9667d28b03a578f2986b04a3a568dd",
        "fe1e280137b74c5496fc1ece35af22d074b2face71f862bc0ae2e7bd57bb58be",
        "9893af31e76c868a2db4892903357fd8352de966d9ec4b815f7fd5898c27610c",
        "59f1b0d0b9e60af537820739fe292cb26c02f11f917b4f3e453f89f435b68c00",
        "4a79fe3655f9f2816709e5ca43698287edcd69bb2f3fdc7a27ff165ad57c5f1c",
        "b1eede6c28d71659b97424c8ce866f3757a458343499ee6f07446f88f8b1d90a",
        "3634deb9e4a8c263d7396d3df6de7cce9525ed12597b0a14734527dd83667764",
        "2c4b75142cdb65fe2d2dad2b9b4b1db18e1b2a09108186b84cce8c1e7076a171",
        "054172fc922448295e7ea8557e5711362777005f3c5be39ef73be4cabdbdb1d3",
        "c3b0879344ea09144147431465e6247d8343444c4316acbb7af1eb9782cc196b",
        "ce331a3fc54692751bc229b9b3dcddf4afefa51004b60d22b2b4bb428210ee56",
        "9ceab5fb68d42209bd942029751b19f81767bc145998d32918001f3ee009d885",
        "a38a4789552de782bd8848a6aac486b9544f9752a79c39f1aa62714b819accc9",
        "ba467e3c63f8ab097e9ef2b8450c533b9afc796ebf384d24432d0746e81b413f",
        "95d9849fc4bba0edf57a18ea01063f5ac26e5ab1342a8dbcb23060201daa0af3",
        "02146113c58bdfc42c47d12c0774d08b4ae9d641839f62e2552c2f47b3040193",
        "5e51a943fbb579181ebdd53babd80cb8c42fdd86825649599294185a8d18122c",
        "7d2b71e0a53ad8c4df84be0727c5301011bc29c46b9325f841cedca7ec549043",
        "e4ece256ef60298a4fe2566babf33623fff2622e23183182e8f13076f84f64da",
        "3ec2db191fe4a97252735d3a4bf1a2c46c8770486037fb2f2a7584da68a12ace",
        "ecc43d0351e18bf6c369696395399c6f39eb7b9776242bbfa59e1fdd5f7943b3",
        "599df179c3d90d6e05eeb2465ddbe15b37fcf36163355238e83c12252748ce98",
        "6c12ec5420f4a480b6854788422c878eb199e732adbf1606c005e9eaa39235e0",
        "8c6617dae7b86095cafa34fcdbd2429fe703773eb59e73031876818f101605f2",
        "0b0dd6ddf824aa00e54ed74bb3e3969bc3ac8b8e7d6591f01dc4af2a6e041667",
        "0898c7088cb6140280d4324c79b22dd93b3cf4df9a2be75354307c7c825e6b55",
        "16fb64136dedbb268a32da125531faf5aa0daa60e2ec8826cdd5bf1664f0aca0",
        "26033016fd303c0c255d51cb1ea6ee8901da7e8167a75c38ef701275a78cd7f9",
        "de92a81d467788b351f840134305a2648977508fd7ce5303c402fee5bec45983",
        "c9a1f031acfe1c08834453ddbf53a08523ad49eb74099f392591ad259d3f2c66",
        "3ae028fdda61ab3690e677c692c7d269bfbdeedfe3c7b1493ee066667a8a89e8",
    ]

    // MARK: - Init

    private init() {
        refreshState()
    }

    // MARK: - Public API

    /// 刷新激活状态 + 剩余试用天数
    func refreshState() {
        isActivated = loadActivationFromKeychain()
        (trialDaysRemaining, trialStartDate) = computeTrialRemaining()
    }

    /// 设置首次启动日期（仅在首次调用时生效）
    func setFirstLaunchDateIfNeeded() {
        guard UserDefaults.standard.string(forKey: Self.trialStartKey) == nil else { return }
        let iso = ISO8601DateFormatter().string(from: Date())
        UserDefaults.standard.set(iso, forKey: Self.trialStartKey)
        VTMLog.app("🕐 试用期已开始: \(iso)")
        refreshState()
    }

    /// 验证激活码（离线）
    /// - Parameter rawCode: 用户输入的原始字符串（可含连字符、空格、大小写）
    /// - Returns: 是否有效
    func validateCode(_ rawCode: String) -> Bool {
        // 1. 清理：去连字符、去空格、转大写
        let cleaned = rawCode
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // 2. 长度检查
        guard cleaned.count == 12 else { return false }

        // 3. 字符合法性检查
        let validChars = CharacterSet(charactersIn: "23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        guard cleaned.rangeOfCharacter(from: validChars.inverted) == nil else { return false }

        // 4. SHA-256 哈希比对
        let hash = sha256(cleaned)
        return validHashes.contains(hash)
    }

    /// 激活应用
    /// - Parameter code: 验证通过的激活码
    /// - Returns: 是否保存成功
    @discardableResult
    func activate(_ code: String) -> Bool {
        guard validateCode(code) else {
            VTMLog.app("❌ 激活码无效")
            return false
        }

        let cleaned = code
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        let success = saveActivationToKeychain(code: cleaned)
        if success {
            VTMLog.app("✅ 激活成功")
            refreshState()
            NotificationCenter.default.post(name: .vtmActivationDidComplete, object: nil)
        }
        return success
    }

    /// 试用是否已过期
    var isTrialExpired: Bool {
        trialDaysRemaining <= 0
    }

    /// 开发者复位：清除所有试用和激活状态
    func resetAll() {
        UserDefaults.standard.removeObject(forKey: Self.trialStartKey)
        deleteActivationFromKeychain()
        refreshState()
        VTMLog.app("🔄 试用 & 激活状态已复位")
    }

    // MARK: - Private: Trial

    private func computeTrialRemaining() -> (Int, Date?) {
        guard let iso = UserDefaults.standard.string(forKey: Self.trialStartKey),
              let startDate = ISO8601DateFormatter().date(from: iso) else {
            return (Self.trialDays, nil) // 未开始试用
        }

        let elapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDays - elapsed)
        return (remaining, startDate)
    }

    // MARK: - Private: Keychain

    private func loadActivationFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.activationKeychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let code = String(data: data, encoding: .utf8) else {
            return false
        }

        // 二次验证：Keychain 里的 code 是否仍然有效
        return validateCode(code)
    }

    private func saveActivationToKeychain(code: String) -> Bool {
        let passwordData = code.data(using: .utf8)!

        // 先删除旧条目
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.activationKeychainKey,
        ] as CFDictionary)

        // 写入新条目
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.activationKeychainKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func deleteActivationFromKeychain() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.activationKeychainKey,
        ] as CFDictionary)
    }

    // MARK: - Private: Crypto

    private func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let vtmActivationDidComplete = Notification.Name("VTMActivationDidComplete")
}
