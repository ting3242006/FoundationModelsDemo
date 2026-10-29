import SwiftUI

struct EventEditorView: View {
    @Binding var event: ReviewedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("標題").font(.subheadline).foregroundStyle(.secondary)
                TextField("標題", text: $event.title)
                    .textFieldStyle(.roundedBorder)
            }
            DatePicker("開始", selection: $event.start)
                .environment(\.timeZone, TimeZone(identifier: event.timeZoneIdentifier) ?? .current)
            Text("時區：\(event.timeZoneIdentifier)").font(.caption).foregroundStyle(.secondary)
            Stepper("持續 \(event.durationMinutes) 分鐘", value: $event.durationMinutes, in: 1...480, step: 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("地點").font(.subheadline).foregroundStyle(.secondary)
                TextField("地點", text: $event.location).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("參與者姓名").font(.subheadline).foregroundStyle(.secondary)
                TextField("參與者姓名", text: $event.attendeeQuery).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("筆記").font(.subheadline).foregroundStyle(.secondary)
                TextField("筆記", text: $event.notes, axis: .vertical)
                    .lineLimit(2...6).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("活動筆記")
            }
            Picker("提醒", selection: $event.reminderMinutesBefore) {
                Text("不提醒").tag(nil as Int?)
                Text("當下").tag(0 as Int?)
                Text("15 分鐘前").tag(15 as Int?)
                Text("兩小時前").tag(120 as Int?)
                Text("前一天").tag(1440 as Int?)
                if let minutes = event.reminderMinutesBefore, ![0,15,120,1440].contains(minutes) {
                    Text("\(minutes) 分鐘前").tag(minutes as Int?)
                }
            }
        }
    }
}

// Shared presentation lives in an existing project file so the generated project stays unchanged.
struct EventPreviewView: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    let event: ReviewedEvent
    var participant: String? = nil

    private var timeZone: TimeZone { TimeZone(identifier: event.timeZoneIdentifier) ?? calendar.timeZone }
    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar, timeZone: timeZone)
    }
    private var timeStyle: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: timeZone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                VStack(spacing: 2) {
                    Text(event.start.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated)))
                        .font(.subheadline.weight(.semibold))
                    Text(event.start.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: timeZone).day()))
                        .font(.largeTitle.weight(.bold))
                }
                .padding(14)
                .foregroundStyle(StudioStyle.accent(for: colorScheme))
                .background(StudioStyle.accent(for: colorScheme).opacity(0.1), in: .rect(cornerRadius: 18))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text(event.start.formatted(dateStyle)).foregroundStyle(.secondary)
                    Text("\(event.start.formatted(timeStyle))–\(event.end.formatted(timeStyle)) · \(event.durationMinutes) 分鐘")
                    Text(event.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Label(event.location.isEmpty ? "尚未指定地點" : event.location, systemImage: "mappin.and.ellipse")
            Label(participant ?? (event.attendeeQuery.isEmpty ? "沒有指定參與者" : event.attendeeQuery), systemImage: "person")
            Label(StudioStyle.reminder(event.reminderMinutesBefore), systemImage: "bell")
            if !event.notes.isEmpty {
                Text(event.notes).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

enum StudioStyle {
    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 154/255, green: 182/255, blue: 1) : Color(red: 49/255, green: 91/255, blue: 199/255)
    }

    static func reminder(_ minutes: Int?) -> String {
        switch minutes {
        case nil: "不提醒"
        case 0: "活動開始時提醒"
        case 15: "15 分鐘前提醒"
        case 120: "兩小時前提醒"
        case 1440: "前一天提醒"
        case .some(let value): "\(value) 分鐘前提醒"
        }
    }
}

struct StudioPrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(StudioStyle.accent(for: colorScheme))
        .foregroundStyle(isEnabled ? (colorScheme == .dark ? Color(red: 18/255, green: 19/255, blue: 22/255) : Color.white) : Color.secondary)
    }
}

struct StudioCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
    }
}

extension View {
    func studioCard() -> some View { modifier(StudioCard()) }
}
