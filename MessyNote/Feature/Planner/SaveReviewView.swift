import SwiftUI

struct SaveReviewView: View {
    let review: SaveReview
    let isSaving: Bool
    let isFixture: Bool
    let error: String?
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最後確認").font(.title2.weight(.bold))
                        Text("確認活動內容，準備好再加入行事曆。")
                            .foregroundStyle(.secondary)
                    }
                    EventPreviewView(event: review.event, participant: review.contact?.displayName)
                        .studioCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Label("參與者只會保留在事件筆記，不會發送邀請。", systemImage: "person.text.rectangle")
                        Label("衝突查詢是當下快照，行事曆內容可能已改變。", systemImage: "clock.arrow.circlepath")
                        if isFixture {
                            Label {
                                Text("將示範草稿寫入系統行事曆。示範資料只替代查詢；以下確認會真的建立事件。")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Text("確認後將寫入系統預設行事曆。")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let error {
                        VStack(alignment: .leading, spacing: 12) {
                            Label { Text("尚未儲存成功") } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(.red) }.font(.headline)
                            Text(error)
                        }
                        .foregroundStyle(.primary)
                        .studioCard()
                    }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("加入行事曆")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if isSaving { ProgressView("正在儲存") }
                    StudioPrimaryButton(title: "確認加入行事曆", symbol: "calendar.badge.plus", action: confirm)
                        .disabled(isSaving)
                    Button("取消", role: .cancel, action: cancel)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}
