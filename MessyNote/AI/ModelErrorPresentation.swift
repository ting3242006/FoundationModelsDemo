import Foundation
import FoundationModels

enum ModelErrorPresentation {
    static func message(for error: any Error) -> String {
        if let error = error as? LanguageModelError {
            switch error {
            case .contextSizeExceeded: return "對話內容已超過模型容量。請重置對話後以較短筆記重試。"
            case .unsupportedLanguageOrLocale: return "模型不支援此語言或語系。請檢查 Apple Intelligence 語言設定。"
            case .guardrailViolation, .refusal: return "模型無法處理這段內容。請改寫為具體的行程筆記後重試。"
            case .timeout: return "模型回應逾時。請稍後重試，或重置對話。"
            case .rateLimited: return "模型暫時忙碌。請稍後重試。"
            default: return "模型無法完成此請求：\(error.localizedDescription)。請重置對話後重試。"
            }
        }
        return error.localizedDescription + " 可修改筆記重試，或重置對話。"
    }
}
