import Foundation
import FoundationModels

enum ModelState: Equatable {
    case available
    case unavailable(String)

    static func current(locale: Locale = .current) -> Self {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(locale) ? .available : .unavailable("不支援目前語系：\(locale.identifier)。請檢查 Apple Intelligence 語言設定。")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable("此裝置不支援 Apple Intelligence。請使用相容實機。")
            case .appleIntelligenceNotEnabled: return .unavailable("請在設定中開啟 Apple Intelligence。")
            case .modelNotReady: return .unavailable("系統模型尚未就緒，可能仍在下載。完成後請重新檢查。")
            @unknown default: return .unavailable("系統模型目前無法使用。")
            }
        }
    }
}
