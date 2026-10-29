import SwiftUI

struct PlannerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = PlannerViewModel()
    @State private var pendingClock = Date.now
    @State private var showSettings = false
    @State private var isEditing = false
    @State private var isNoteExpanded = false
    @State private var showActivity = false
    @ScaledMetric(relativeTo: .body) private var noteEditorHeight = 120.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        introduction
                        let wide = geometry.size.width >= 840 && !dynamicTypeSize.isAccessibilitySize
                        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 24)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
                        layout {
                            noteCard(wide: wide).frame(maxWidth: .infinity)
                            resultColumn.frame(maxWidth: .infinity)
                        }
                        activityCard
                    }
                    .padding(20)
                    .frame(maxWidth: 1180)
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("MessyNote")
            .navigationBarTitleDisplayMode(.inline)
            .tint(StudioStyle.accent(for: colorScheme))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("設定", systemImage: "ellipsis.circle") { showSettings = true }
                        .popover(isPresented: $showSettings) { settings }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.isLoading { loadingActions }
                else if model.event != nil { saveActions }
            }
            .onChange(of: model.event != nil) { if model.event != nil { isNoteExpanded = false } }
            .onChange(of: scenePhase) { if scenePhase == .active { model.availability = .current() } }
            .onDisappear { if model.isLoading { model.cancel() } }
            .sheet(item: $model.presentedReview) { review in
                SaveReviewView(review: review, isSaving: model.saver.isSaving, isFixture: model.isFixture, error: model.error,
                    confirm: { Task { await model.confirmSave(review) } }, cancel: model.cancelReview)
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("把想法，排進生活").font(.largeTitle.weight(.bold))
            Text("記下時間、地點和同行的人，讓筆記慢慢成為一個計畫。")
                .foregroundStyle(.secondary)
            switch model.availability {
            case .available:
                Label("裝置端模型可使用", systemImage: "sparkles").font(.subheadline).foregroundStyle(.secondary)
            case .unavailable(let message):
                Label(message, systemImage: "exclamationmark.circle").font(.subheadline)
            }
            #if DEBUG
            if model.isFixture {
                VStack(alignment: .leading, spacing: 6) {
                    Label { Text("示範資料模式") } icon: { Image(systemName: "testtube.2").foregroundStyle(.orange) }.font(.subheadline.weight(.semibold))
                    Text("真實模型推論＋示範聯絡人與行事曆查詢。儲存仍會寫入系統行事曆。")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
            } else {
                Text("使用系統資料").font(.caption).foregroundStyle(.secondary)
            }
            #endif
        }
    }

    private func noteCard(wide: Bool) -> some View {
        Group {
            if model.event != nil && !wide {
                DisclosureGroup(isExpanded: $isNoteExpanded) {
                    noteContent.padding(.top, 20)
                } label: {
                    Label("筆記與修改指令", systemImage: "square.and.pencil")
                        .font(.headline).frame(minHeight: 44)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if model.event != nil {
                        Label("筆記與修改指令", systemImage: "square.and.pencil")
                            .font(.title2.weight(.semibold))
                    }
                    noteContent
                }
            }
        }
        .studioCard()
    }

    private var noteContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.event == nil {
                Label(model.draft == nil ? "隨手筆記" : "補充筆記", systemImage: "square.and.pencil")
                    .font(.title2.weight(.semibold))
            }
            TextEditor(text: $model.input)
                .scrollContentBackground(.hidden)
                .frame(height: noteEditorHeight)
                .overlay(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text("今天想做什麼？")
                            .foregroundStyle(Color(uiColor: .placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("隨手筆記或修改指令")
            Text(model.draft == nil ? "日期、時間或提醒方式，都可以用平常說話的方式寫下。" : "想調整活動？在這裡補充一句話，再整理一次。")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("填入範例筆記", systemImage: "text.badge.plus", action: model.fillExample)
                .frame(minHeight: 44)
                .disabled(model.isLoading || model.saver.isSaving || model.saver.saved)
            StudioPrimaryButton(title: "整理成活動", symbol: "sparkles", action: model.generate)
                .disabled(model.availability != .available || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.saver.isSaving)
        }
    }

    private var loadingActions: some View {
        VStack(spacing: 8) {
            ProgressView("正在整理筆記與查詢資料")
            Button("取消", systemImage: "stop.circle", action: model.cancel)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 680).frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var resultColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            if model.isLoading, let partial = model.partial {
                VStack(alignment: .leading, spacing: 16) {
                    Text("正在整理活動").font(.caption).foregroundStyle(.secondary)
                    Text("活動逐漸成形").font(.title2.weight(.semibold))
                    if let title = partial.title { Text(title).font(.headline) }
                    if let hour = partial.hour, let minute = partial.minute { Label("時間：\(hour):\(minute.formatted(.number.precision(.integerLength(2))))", systemImage: "clock") }
                    if let location = partial.location { Label(location, systemImage: "mappin.and.ellipse") }
                    if let attendee = partial.attendeeQuery { Label(attendee, systemImage: "person") }
                    if let notes = partial.notes { Text(notes).foregroundStyle(.secondary) }
                    Text("這是模型目前產生的內容，完成後仍可修改。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .studioCard()
                .transition(.opacity)
            }
            if model.isLoading, let clock = model.clockPartial {
                VStack(alignment: .leading, spacing: 12) {
                    Text("正在補充時間").font(.headline)
                    if let hour = clock.hour { Text("小時：\(hour)") }
                    if let minute = clock.minute { Text("分鐘：\(minute)") }
                }.studioCard()
            }
            if let event = model.event {
                VStack(alignment: .leading, spacing: 20) {
                    Text("活動預覽").font(.caption).foregroundStyle(.secondary)
                    EventPreviewView(event: event, participant: model.selectedContact?.displayName)
                    DisclosureGroup(isExpanded: $isEditing) {
                        EventEditorView(event: model.editorBinding(for: event)).padding(.top, 16)
                    } label: {
                        Label("編輯", systemImage: "slider.horizontal.3").font(.headline).frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("eventEditorDisclosure")
                    .disabled(model.isLoading || model.saver.isSaving || model.saver.saved)
                }.studioCard()
                contactCard
                calendarCard
            } else if let draft = model.draft, !model.isLoading {
                VStack(alignment: .leading, spacing: 16) {
                    Text("尚待時間確認").font(.caption).foregroundStyle(.secondary)
                    Label("再補一個時間就好", systemImage: "clock.badge.questionmark").font(.title2.weight(.semibold))
                    Text(draft.title).font(.headline)
                    if let day = model.pendingDay {
                        Text("固定草稿日期：\(day.formatted(date: .complete, time: .omitted))")
                        Text("請先在筆記裡補充確切時間；也可手動選擇並確認作為備用。選擇器顯示值不是模型抽取結果。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        DatePicker("使用者選擇的時間", selection: $pendingClock, displayedComponents: .hourAndMinute)
                        Button("使用此時間並查詢") { model.completePendingTime(pendingClock) }
                            .frame(minHeight: 44)
                            .disabled(model.availability != .available || model.saver.isSaving)
                    } else {
                        Text("請在筆記裡補充確切日期或時間，再整理一次。")
                    }
                }.studioCard()
            } else if !model.isLoading {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "calendar.badge.clock").font(.largeTitle).foregroundStyle(StudioStyle.accent(for: colorScheme))
                        .accessibilityHidden(true)
                    Text("為下一件事，留個位置").font(.title2.weight(.semibold))
                    Text("整理後的活動會出現在這裡。你可以先看內容、調整細節，最後再決定是否加入行事曆。")
                        .foregroundStyle(.secondary)
                }.studioCard()
            }
            if let error = model.error {
                VStack(alignment: .leading, spacing: 12) {
                    Label { Text("需要注意") } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(.red) }.font(.headline)
                    Text("這次操作未完成。請查看原因，調整筆記或稍後再試。")
                    DisclosureGroup("原始診斷") { Text(error).font(.subheadline).textSelection(.enabled).padding(.top, 8) }
                }.studioCard()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.isLoading)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("參與者確認", systemImage: "person.crop.circle").font(.headline)
            if let error = model.ledger.contactError {
                Label { Text(error) } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            if let selected = model.selectedContact { Label("已選擇：\(selected.displayName)", systemImage: "checkmark.circle") }
            if let candidates = model.ledger.candidates {
                if candidates.isEmpty { Text("找不到可存取的聯絡人（可能受限於部分存取權）。") }
                ForEach(candidates) { candidate in
                    Button(candidate.displayName) { model.selectedContact = candidate; model.proceedUnresolved = false }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                }
            } else { Text("尚未取得此草稿的聯絡人查詢結果。").foregroundStyle(.secondary) }
            if model.event?.attendeeQuery.isEmpty == false {
                Toggle("保留原姓名，繼續但不指定聯絡人", isOn: $model.proceedUnresolved)
                    .onChange(of: model.proceedUnresolved) { if model.proceedUnresolved { model.selectedContact = nil } }
            }
            Text("僅保存參與者姓名到事件筆記，不發送邀請。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .studioCard()
        .disabled(model.isLoading || model.saver.isSaving || model.saver.saved)
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("行事曆查詢", systemImage: "calendar").font(.headline)
            if let error = model.ledger.calendarError {
                Label { Text(error) } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            if let conflicts = model.ledger.conflicts {
                ForEach(conflicts) { conflict in
                    Text("⚠ \(conflict.title) · \(conflict.start.formatted(date: .omitted, time: .shortened))–\(conflict.end.formatted(date: .omitted, time: .shortened))")
                }
                if conflicts.isEmpty { Label("此時段沒有衝突（查詢當下）", systemImage: "checkmark.circle") }
            } else { Text("未有有效查詢證據；衝突狀態未知。").foregroundStyle(.secondary) }
            if let slot = model.ledger.nextSlot {
                Text("建議時段：\(slot.formatted(date: .abbreviated, time: .shortened))")
                Button("接受建議時間", action: model.acceptSlot)
                    .frame(minHeight: 44)
                    .disabled(model.isLoading || model.saver.isSaving || model.saver.saved)
            }
        }.studioCard()
    }

    private var activityCard: some View {
        DisclosureGroup(isExpanded: $showActivity) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.ledger.activity) { item in Text(item.message).font(.caption).textSelection(.enabled) }
                if model.ledger.activity.isEmpty { Text("尚未執行推論或工具查詢").foregroundStyle(.secondary) }
            }.padding(.top, 16)
        } label: {
            Label("AI 處理紀錄", systemImage: "text.alignleft").font(.headline).frame(minHeight: 44)
        }
        .accessibilityIdentifier("activityDisclosure")
        .studioCard()
    }

    private var saveActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let success = model.success {
                Label { Text(success) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }.font(.headline)
            } else {
                StudioPrimaryButton(title: "檢查並加入", symbol: "calendar.badge.plus", action: model.prepareSave)
                    .disabled(!model.canSave)
                Text("先確認內容，下一步才會寫入行事曆。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 680).frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("工作室") {
                    Button("重新檢查", systemImage: "arrow.clockwise") { model.availability = .current() }
                    Button("重置對話", systemImage: "arrow.counterclockwise") {
                        model.reset(); isEditing = false; showActivity = false; showSettings = false
                    }.disabled(model.saver.isSaving)
                }
                #if DEBUG
                Section("Demo Mode") {
                    Toggle("Demo Fixture Mode", isOn: $model.fixtureMode).disabled(model.saver.isSaving)
                    Text("只替代聯絡人與行事曆查詢。最後確認仍會寫入系統行事曆。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("工作室設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showSettings = false } } }
        }
        .presentationDetents([.medium, .large])
        .frame(idealWidth: 380, idealHeight: 400)
    }
}
