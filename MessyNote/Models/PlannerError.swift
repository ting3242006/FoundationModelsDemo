import Foundation

enum PlannerError: LocalizedError {
    case invalidDate, missingTime, denied(String), invalidDraft, staleReview
    var errorDescription: String? {
        switch self {
        case .invalidDate: "日期或時間無效，請修改後重試。"
        case .missingTime: "尚未指定確切時間。請輸入例如「改成晚上七點半」。"
        case .denied(let resource): "未允許讀取\(resource)。草稿仍保留，可在系統設定調整權限。"
        case .invalidDraft: "請確認標題、時間與持續時間。"
        case .staleReview: "草稿已變更或已儲存，請重新檢查。"
        }
    }
}
