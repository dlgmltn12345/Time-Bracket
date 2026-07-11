import SwiftUI
import UIKit

struct ShareCalendarSheet: View {
    let meeting: HomeMeeting
    let availabilityCount: Int
    let onCancel: () -> Void
    let onShare: () -> Void

    private var inviteeInitials: [String] {
        Array(meeting.memberInitials.dropFirst())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("팀원에게 공유")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("팀원들이 각자의 시간을 입력할 수 있게 보냅니다.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ShareSummaryRow(
                        title: meeting.title,
                        detail: meeting.dateRange,
                        systemImage: "calendar.badge.clock",
                        tint: Color(uiColor: .systemBlue),
                        isLast: false
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemPurple))
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .systemPurple).opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("초대 대상")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(inviteeSummary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        AvatarStack(names: inviteeInitials, maxVisible: 5)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 66)
                }
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("공유")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 18) {
                            ForEach(ShareAction.allCases) { action in
                                ShareActionButton(item: action) {
                                    handleShareAction(action)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                    .scrollClipDisabled()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 32)
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
            }
        }
    }

    private var inviteeSummary: String {
        let inviteeCount = max(meeting.memberCount - 1, 0)
        guard inviteeCount > 0 else {
            return "추가된 팀원이 없습니다"
        }

        return "\(inviteeCount)명에게 공유"
    }

    private func handleShareAction(_ action: ShareAction) {
        switch action {
        case .copyLink:
            UIPasteboard.general.string = shareURL.absoluteString
            onShare()
        case .slack, .teams, .discord, .gmail, .notion, .messages:
            UIPasteboard.general.string = shareMessage
            onShare()
        }
    }

    private var shareMessage: String {
        """
        \(meeting.title) 회의 시간 조율에 참여해주세요.

        후보 기간: \(meeting.dateRange)
        조율 시간: \(meeting.timeRange)
        입력 링크: \(shareURL.absoluteString)
        """
    }

    private var shareURL: URL {
        URL(string: "https://timebracket.app/invite/\(meeting.id)") ?? URL(string: "https://timebracket.app")!
    }
}

enum ShareAction: String, Identifiable {
    case copyLink
    case slack
    case teams
    case discord
    case gmail
    case notion
    case messages

    static let allCases: [ShareAction] = [.copyLink, .messages, .slack, .gmail, .teams, .discord, .notion]

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .copyLink:
            return "링크 복사"
        case .slack:
            return "Slack"
        case .teams:
            return "Teams"
        case .discord:
            return "Discord"
        case .gmail:
            return "Gmail"
        case .notion:
            return "Notion"
        case .messages:
            return "메시지"
        }
    }

    var assetName: String? {
        switch self {
        case .copyLink:
            return nil
        case .slack:
            return "ShareSlack"
        case .teams:
            return "ShareTeams"
        case .discord:
            return "ShareDiscord"
        case .gmail:
            return "ShareGmail"
        case .notion:
            return "ShareNotion"
        case .messages:
            return "ShareMessages"
        }
    }

    var background: Color {
        switch self {
        case .copyLink, .slack, .gmail, .teams, .discord, .notion, .messages:
            return Color(uiColor: .tertiarySystemFill)
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .copyLink:
            return 30
        case .slack, .teams, .discord, .gmail, .notion, .messages:
            return 42
        }
    }

    var hasBorder: Bool {
        false
    }
}

struct ShareActionButton: View {
    let item: ShareAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 9) {
                ShareActionIcon(item: item)
                    .frame(width: 74, height: 74)

                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 82, height: 34, alignment: .top)
            }
            .frame(width: 82, height: 117, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ShareActionIcon: View {
    let item: ShareAction

    var body: some View {
        ZStack {
            Circle()
                .fill(item.background)

            switch item {
            case .copyLink:
                Image(systemName: "link")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label))
            case .slack, .teams, .discord, .gmail, .notion, .messages:
                if let assetName = item.assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: item.iconSize, height: item.iconSize)
                }
            }
        }
        .overlay {
            if item.hasBorder {
                Circle()
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.8)
            }
        }
    }
}

struct ShareSummaryRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 66)

            if !isLast {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }
}

struct AvailabilityReasonSheet: View {
    let draft: AvailabilityReasonDraft
    let calendar: Calendar
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var reason: String
    @State private var selectedBurdenCategory: BurdenCategory
    @FocusState private var isReasonFocused: Bool

    init(
        draft: AvailabilityReasonDraft,
        calendar: Calendar,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.calendar = calendar
        self.onCancel = onCancel
        self.onSave = onSave
        _reason = State(initialValue: Self.cleanedReasonText(draft.initialReason))
        _selectedBurdenCategory = State(initialValue: Self.initialBurdenCategory(for: draft.initialReason))
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(draft.mode.reasonTitle)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(selectionSummary)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    suggestionChips

                    if draft.mode == .burden {
                        burdenCategoryMenu
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("사유")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        ZStack(alignment: .topLeading) {
                            if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(draft.mode.reasonPlaceholder)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                            }

                            TextEditor(text: $reason)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.primary)
                                .focused($isReasonFocused)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .frame(minHeight: 108, maxHeight: 132)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 0.8)
                        }
                    }
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(reasonForSaving)
                    }
                    .fontWeight(.semibold)
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(reasonSuggestionRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { suggestion in
                        reasonChip(suggestion)
                    }

                    if row.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 36)
            }
        }
        .frame(height: 80, alignment: .top)
    }

    private func reasonChip(_ suggestion: ReasonSuggestion) -> some View {
        let isSelected = reason == suggestion.reason

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                reason = suggestion.reason
                suggestion.category.map { selectedBurdenCategory = $0 }
            }
        } label: {
            Text(suggestion.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : draft.mode.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? draft.mode.tint : draft.mode.tint.opacity(0.12),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(draft.mode.tint.opacity(isSelected ? 0 : 0.14), lineWidth: 0.8)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var burdenCategoryMenu: some View {
        HStack(spacing: 12) {
            Text("부담 유형")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Menu {
                ForEach(BurdenCategory.allCases) { category in
                    Button {
                        selectedBurdenCategory = category
                    } label: {
                        Label(category.burdenTitle, systemImage: category.symbolName)
                    }
                }

                Divider()

                Button {
                    selectedBurdenCategory = .personal
                    isReasonFocused = true
                } label: {
                    Label("사용자화", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: selectedBurdenCategory.symbolName)
                        .font(.system(size: 13, weight: .semibold))

                    Text(selectedBurdenCategory.burdenTitle)
                        .font(.system(size: 15, weight: .semibold))

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                .foregroundStyle(draft.mode.tint)
                .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .buttonStyle(.plain)
    }

    private var reasonForSaving: String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        guard draft.mode == .burden else {
            return trimmedReason
        }

        return "\(selectedBurdenCategory.title): \(trimmedReason)"
    }

    private var reasonSuggestions: [ReasonSuggestion] {
        switch draft.mode {
        case .available:
            return []
        case .burden:
            return [
                ReasonSuggestion(title: "준비 시간 부족", reason: "바로 전 일정이 끝난 직후라 회의 준비 시간이 부족합니다.", category: .schedule),
                ReasonSuggestion(title: "이동 부담", reason: "다른 장소에서 복귀해야 해서 시작 시간이 불안정합니다.", category: .movement),
                ReasonSuggestion(title: "집중 회복 필요", reason: "연속된 일정으로 집중력이 떨어질 수 있어 짧은 회복 시간이 필요합니다.", category: .focus),
                ReasonSuggestion(title: "개인 일정", reason: "개인 일정 전후라 안정적으로 참여하기 어렵습니다.", category: .personal)
            ]
        case .unavailable:
            return draft.mode.reasonSuggestions.map {
                ReasonSuggestion(title: draft.mode.reasonSuggestionTitle(for: $0), reason: $0, category: nil)
            }
        }
    }

    private var reasonSuggestionRows: [[ReasonSuggestion]] {
        stride(from: 0, to: reasonSuggestions.count, by: 2).map { index in
            Array(reasonSuggestions[index..<min(index + 2, reasonSuggestions.count)])
        }
    }

    private var selectionSummary: String {
        let sortedSlots = draft.slots.sorted {
            if calendar.isDate($0.date, inSameDayAs: $1.date) {
                return $0.hour < $1.hour
            }

            return $0.date < $1.date
        }

        guard let firstSlot = sortedSlots.first, let lastSlot = sortedSlots.last else {
            return "선택한 시간"
        }

        let startText = dateText(for: firstSlot.date)
        let endText = dateText(for: lastSlot.date)
        let timeText = "\(firstSlot.hour)시-\(lastSlot.hour + 1)시"

        if calendar.isDate(firstSlot.date, inSameDayAs: lastSlot.date) {
            return "\(startText) · \(timeText)"
        }

        return "\(startText) - \(endText) · \(timeText)"
    }

    private func dateText(for date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayIndex = max(calendar.component(.weekday, from: date) - 1, 0)
        let weekday = weekdaySymbols[min(weekdayIndex, weekdaySymbols.count - 1)]
        return "\(components.month ?? 0)월 \(components.day ?? 0)일 (\(weekday))"
    }

    private static func initialBurdenCategory(for reason: String) -> BurdenCategory {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedReason.isEmpty else {
            return .schedule
        }

        return BurdenCategory.classify(reason: trimmedReason)
    }

    private static func cleanedReasonText(_ reason: String) -> String {
        ResponseReasonFormatter.displayText(from: reason)
    }
}

struct AvailabilityEntry {
    let mode: AvailabilityMode
    let reason: String?
}

struct AvailabilityReasonDraft: Identifiable {
    let id = UUID()
    let mode: AvailabilityMode
    let slots: Set<AvailabilitySlot>
    let initialReason: String
}

struct ReasonSuggestion: Hashable {
    let title: String
    let reason: String
    let category: BurdenCategory?

    static func == (lhs: ReasonSuggestion, rhs: ReasonSuggestion) -> Bool {
        lhs.reason == rhs.reason && lhs.category == rhs.category
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(reason)
        hasher.combine(category)
    }
}

enum AvailabilityMode: String, CaseIterable, Identifiable {
    case available
    case burden
    case unavailable

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .available:
            return "가능"
        case .burden:
            return "부담"
        case .unavailable:
            return "불가"
        }
    }

    var tint: Color {
        switch self {
        case .available:
            return Color(uiColor: .systemGreen)
        case .burden:
            return Color(uiColor: .systemOrange)
        case .unavailable:
            return Color(uiColor: .systemRed)
        }
    }

    var blockFill: Color {
        switch self {
        case .available:
            return Color(red: 0.88, green: 0.97, blue: 0.91)
        case .burden:
            return Color(red: 1.0, green: 0.94, blue: 0.84)
        case .unavailable:
            return Color(red: 1.0, green: 0.90, blue: 0.90)
        }
    }

    var blockStroke: Color {
        switch self {
        case .available:
            return Color(red: 0.58, green: 0.84, blue: 0.65)
        case .burden:
            return Color(red: 0.96, green: 0.72, blue: 0.34)
        case .unavailable:
            return Color(red: 0.94, green: 0.62, blue: 0.62)
        }
    }

    var requiresReason: Bool {
        self != .available
    }

    var reasonTitle: String {
        switch self {
        case .available:
            return "가능 시간"
        case .burden:
            return "부담되는 이유"
        case .unavailable:
            return "불가능한 이유"
        }
    }

    var reasonPlaceholder: String {
        switch self {
        case .available:
            return ""
        case .burden:
            return "예: 바로 전 일정이 있어 준비 시간이 필요해요"
        case .unavailable:
            return "예: 이미 확정된 회의가 있어 참석이 어려워요"
        }
    }

    var reasonSuggestions: [String] {
        switch self {
        case .available:
            return []
        case .burden:
            return [
                "바로 전 일정이 끝난 직후라 회의 준비 시간이 부족합니다.",
                "다른 장소에서 복귀해야 해서 시작 시간이 불안정합니다.",
                "연속된 일정으로 집중력이 떨어질 수 있어 짧은 회복 시간이 필요합니다.",
                "개인 일정 전후라 안정적으로 참여하기 어렵습니다."
            ]
        case .unavailable:
            return ["확정된 회의와 겹침", "외부 미팅 이동 중", "휴가/반차로 참석 불가", "병원/가족 일정"]
        }
    }

    func reasonSuggestionTitle(for suggestion: String) -> String {
        switch suggestion {
        case "바로 전 일정이 끝난 직후라 회의 준비 시간이 부족합니다.":
            return "준비 시간 부족"
        case "다른 장소에서 복귀해야 해서 시작 시간이 불안정합니다.":
            return "이동 부담"
        case "연속된 일정으로 집중력이 떨어질 수 있어 짧은 회복 시간이 필요합니다.":
            return "집중 회복 필요"
        case "개인 일정 전후라 안정적으로 참여하기 어렵습니다.":
            return "개인 일정"
        case "확정된 회의와 겹침":
            return "회의 겹침"
        case "외부 미팅 이동 중":
            return "이동 중"
        case "휴가/반차로 참석 불가":
            return "휴가/반차"
        case "병원/가족 일정":
            return "개인 일정"
        default:
            return suggestion
        }
    }
}
