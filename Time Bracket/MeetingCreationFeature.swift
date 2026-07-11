import SwiftUI
import UIKit

struct CreateMeetingSheet: View {
    let defaultStartDate: Date
    let onCancel: () -> Void
    let onCreate: ([MeetingDraft]) -> Void

    @State private var meetingInfo: MeetingInfoDraft
    @State private var calendarSections = ["디자인팀", "제품팀", "리서치", "브랜드"]
    @State private var isAddSectionPresented = false
    @State private var newSectionName = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var scheduleMonth: Date
    @State private var availabilityStartMinutes = 9 * 60
    @State private var availabilityEndMinutes = 18 * 60
    @State private var excludedTimeRule: ExcludedTimeRule = .lunch
    @State private var isCustomExcludedTimePresented = false
    @State private var members: [MeetingMemberDraft] = []
    @State private var currentStep: CreateMeetingStep = .schedule
    @State private var hasVisitedInfoStep = false
    @State private var isParticipantPickerPresented = false
    @State private var participantTargetCount = Self.defaultParticipantTargetCount
    @FocusState private var focusedInfoField: MeetingInfoField?

    private let calendar: Calendar
    private let availableMembers = TeamMember.sampleMembers
    private static let hostParticipantCount = 1
    private static let defaultParticipantTargetCount = 6
    private static let minParticipantTargetCount = 2
    private static let maxParticipantTargetCount = 6

    private var maxInviteeCount: Int {
        participantTargetCount - Self.hostParticipantCount
    }

    private var participantTargetRange: ClosedRange<Int> {
        max(Self.minParticipantTargetCount, members.count + Self.hostParticipantCount)...Self.maxParticipantTargetCount
    }

    init(
        defaultStartDate: Date,
        onCancel: @escaping () -> Void,
        onCreate: @escaping ([MeetingDraft]) -> Void
    ) {
        self.defaultStartDate = defaultStartDate
        self.onCancel = onCancel
        self.onCreate = onCreate

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ko_KR")
        self.calendar = calendar

        _meetingInfo = State(initialValue: MeetingInfoDraft.defaultDraft())
        _startDate = State(initialValue: nil)
        _endDate = State(initialValue: nil)
        _scheduleMonth = State(initialValue: calendar.dateInterval(of: .month, for: defaultStartDate)?.start ?? defaultStartDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CreateMeetingStepBar(
                    currentStep: currentStep,
                    isStepComplete: isRequiredInputComplete,
                    isStepAccessible: isStepAccessible,
                    onSelect: { step in
                        guard isStepAccessible(step) else {
                            return
                        }

                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            if step == .info {
                                hasVisitedInfoStep = true
                            }

                            currentStep = step
                        }
                    }
                )

                stepContent
            }
            .navigationTitle("새 회의 조율")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }

                if currentStep == .participants {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("생성", action: submit)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Color(uiColor: .systemBlue))
                            .disabled(!canSubmit)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("완료") {
                        focusedInfoField = nil
                    }
                    .padding(.vertical, 5)
                    .padding(.trailing, 6)
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $isParticipantPickerPresented) {
            ParticipantPickerSheet(
                availableMembers: availableMembers,
                maxInviteeCount: maxInviteeCount,
                selectedMembers: $members
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("새 캘린더", isPresented: $isAddSectionPresented) {
            TextField("캘린더 이름", text: $newSectionName)
                .textContentType(.none)
                .autocorrectionDisabled(true)

            Button("취소", role: .cancel) {
                newSectionName = ""
            }

            Button("추가") {
                addCalendarSection()
            }
            .disabled(newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("회의를 묶을 캘린더를 추가합니다.")
        }
        .sheet(isPresented: $isCustomExcludedTimePresented) {
            CustomExcludedTimeSheet(
                initialRule: excludedTimeRule.isCustom ? excludedTimeRule : .customDefault,
                onCancel: {
                    isCustomExcludedTimePresented = false
                },
                onSave: { rule in
                    excludedTimeRule = rule
                    isCustomExcludedTimePresented = false
                }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        if currentStep == .participants {
            List {
                CurrentStepHeader(title: currentStep.sectionTitle)
                    .listRowInsets(CreateMeetingLayout.headerListRowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ParticipantLimitSummaryRow(
                    totalParticipantCount: $participantTargetCount,
                    selectedInviteeCount: members.count,
                    maxInviteeCount: maxInviteeCount,
                    participantRange: participantTargetRange
                )
                .padding(.horizontal, CreateMeetingLayout.cardContentPadding)
                .frame(height: CreateMeetingLayout.summaryRowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
                )
                .listRowInsets(CreateMeetingLayout.contentListRowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                HostParticipantRow(isLast: members.isEmpty)
                    .background(
                        ParticipantRowBackground(
                            isFirst: true,
                            isLast: members.isEmpty
                        )
                    )
                    .listRowInsets(
                        CreateMeetingLayout.participantCardRowInsets(
                            isFirst: true,
                            isLast: members.isEmpty
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(Array($members.enumerated()), id: \.element.id) { index, $member in
                    SelectedParticipantRow(
                        member: $member,
                        isFirst: false,
                        isLast: index == members.count - 1
                    )
                    .background(
                        ParticipantRowBackground(
                            isFirst: false,
                            isLast: index == members.count - 1
                        )
                    )
                    .listRowInsets(
                        CreateMeetingLayout.participantCardRowInsets(
                            isFirst: false,
                            isLast: index == members.count - 1
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeMember(member)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color(uiColor: .systemRed))
                        }
                        .tint(Color(uiColor: .systemRed))
                    }
                }

                Button {
                    isParticipantPickerPresented = true
                } label: {
                    CreateMeetingAddActionButton(title: "참석자 추가", isDisabled: members.count >= maxInviteeCount)
                }
                .buttonStyle(.plain)
                .disabled(members.count >= maxInviteeCount)
                .listRowInsets(CreateMeetingLayout.footerListRowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
        } else if currentStep == .info {
            meetingInfoList
        } else {
            List {
                CurrentStepHeader(title: currentStep.sectionTitle)
                    .listRowInsets(CreateMeetingLayout.headerListRowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if currentStep == .schedule {
                    scrollStepEditor
                        .listRowInsets(CreateMeetingLayout.singleContentListRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    VStack(spacing: 0) {
                        scrollStepEditor
                    }
                    .padding(CreateMeetingLayout.cardContentPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
                    )
                    .listRowInsets(CreateMeetingLayout.singleContentListRowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedInfoField = nil
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var meetingInfoList: some View {
        List {
            CurrentStepHeader(title: currentStep.sectionTitle)
                .listRowInsets(CreateMeetingLayout.headerListRowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            MeetingInfoCard(
                info: $meetingInfo,
                sections: calendarSections,
                focusedField: $focusedInfoField,
                onSelectSection: { section in
                    meetingInfo.sectionName = section
                },
                onAddSection: {
                    focusedInfoField = nil
                    newSectionName = ""
                    isAddSectionPresented = true
                }
            )
            .listRowInsets(CreateMeetingLayout.singleContentListRowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.vertical, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private var scrollStepEditor: some View {
        switch currentStep {
        case .schedule:
            scheduleEditor
        case .info:
            EmptyView()
        case .participants:
            EmptyView()
        }
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: CreateMeetingLayout.contentSpacing) {
            DateRangeCalendarPicker(
                displayedMonth: $scheduleMonth,
                startDate: $startDate,
                endDate: $endDate,
                calendar: calendar
            )

            VStack(spacing: 0) {
                scheduleSettingRow(title: "소요 시간", systemImage: "hourglass") {
                    Text(meetingDurationText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Divider()

                scheduleSettingRow(title: "조율 시간대", systemImage: "clock") {
                    HStack(spacing: 7) {
                        availabilityTimeMenu(
                            text: timeText(for: availabilityStartMinutes),
                            options: availabilityStartOptions,
                            selectedMinutes: availabilityStartMinutes,
                            onSelect: setAvailabilityStart
                        )

                        Text("-")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 1)

                        availabilityTimeMenu(
                            text: timeText(for: availabilityEndMinutes),
                            options: availabilityEndOptions,
                            selectedMinutes: availabilityEndMinutes,
                            onSelect: setAvailabilityEnd
                        )
                    }
                }

                Divider()

                scheduleSettingRow(title: "제외 시간", systemImage: "minus.circle") {
                    excludedTimeMenu
                }
            }
            .padding(.horizontal, CreateMeetingLayout.cardContentPadding)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
        }
    }

    private func scheduleSettingRow<Trailing: View>(
        title: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .frame(width: 20, height: 20, alignment: .center)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
                .frame(height: 24, alignment: .leading)
                .frame(minWidth: 106, alignment: .leading)

            Spacer(minLength: 16)

            trailing()
                .frame(minHeight: 32, alignment: .center)
        }
        .frame(height: CreateMeetingLayout.rowHeight)
    }

    private var scheduleSummaryChips: [String] {
        [
            candidateRangeText,
            availabilityWindowText,
            meetingDurationText,
            excludedTimeText
        ]
    }

    private var meetingInfoSummaryChips: [String] {
        return [
            sanitizedTitle(for: meetingInfo).isEmpty ? "회의명 미입력" : sanitizedTitle(for: meetingInfo),
            meetingInfo.sectionName,
            meetingInfo.meetingMode.title
        ]
    }

    private var participantSummaryChips: [String] {
        let requiredCount = members.filter(\.isRequired).count
        let optionalCount = members.count - requiredCount
        return [
            "총 \(participantTargetCount)명",
            "초대 \(members.count)명",
            "필참 \(requiredCount) · 선택 \(optionalCount)"
        ]
    }

    private var participantRequirementText: String {
        return "초대 \(sanitizedMembers.count)명 · 필참 \(requiredParticipantCount) · 선택 \(optionalParticipantCount)"
    }

    private var primaryReviewMeetingInfo: MeetingInfoDraft {
        meetingInfo
    }

    private var primaryReviewMeetingTitle: String {
        sanitizedTitle(for: primaryReviewMeetingInfo).isEmpty ? "회의 정보" : sanitizedTitle(for: primaryReviewMeetingInfo)
    }

    private var primaryReviewMeetingMode: String {
        primaryReviewMeetingInfo.meetingMode.title
    }

    private var primaryReviewMeetingLocation: String {
        sanitizedLocation(for: primaryReviewMeetingInfo)
    }

    private var requiredParticipantCount: Int {
        sanitizedMembers.filter(\.isRequired).count
    }

    private var optionalParticipantCount: Int {
        sanitizedMembers.count - requiredParticipantCount
    }

    private var candidateRangeText: String {
        guard let startDate else {
            return "일정 미정"
        }

        guard let endDate else {
            return "\(shortDateText(for: startDate))부터"
        }

        let dates = candidateDates(from: startDate, to: endDate)
        guard let firstDate = dates.first else {
            return "일정 미정"
        }

        guard let lastDate = dates.last, !calendar.isDate(firstDate, inSameDayAs: lastDate) else {
            return shortDateText(for: firstDate)
        }

        return "\(shortDateText(for: firstDate)) - \(shortDateText(for: lastDate))"
    }

    private var candidateRangeDetailText: String {
        guard let startDate else {
            return "일정 미정"
        }

        guard let endDate else {
            return "\(shortWeekdayDateText(for: startDate))부터"
        }

        let dates = candidateDates(from: startDate, to: endDate)
        guard let firstDate = dates.first else {
            return "일정 미정"
        }

        guard let lastDate = dates.last, !calendar.isDate(firstDate, inSameDayAs: lastDate) else {
            return shortWeekdayDateText(for: firstDate)
        }

        return "\(shortWeekdayDateText(for: firstDate)) - \(shortWeekdayDateText(for: lastDate))"
    }

    private var availabilityWindowText: String {
        "\(timeText(for: availabilityStartMinutes)) - \(timeText(for: availabilityEndMinutes))"
    }

    private var meetingDurationText: String {
        "1시간"
    }

    private var excludedTimeText: String {
        excludedTimeRule.summaryText
    }

    private var candidateDayCount: Int {
        candidateDateRows.count
    }

    private var candidateDateRows: [ReviewCandidateDateRow] {
        guard let startDate, let endDate else {
            return []
        }

        return candidateDates(from: startDate, to: endDate).map { date in
            ReviewCandidateDateRow(
                dateText: fullDateText(for: date),
                weekday: weekdayText(for: date),
                isWeekend: isWeekend(date)
            )
        }
    }

    private var availabilityStartOptions: [Int] {
        stride(from: 7 * 60, through: 21 * 60, by: 30).map { $0 }
    }

    private var availabilityEndOptions: [Int] {
        stride(from: availabilityStartMinutes + 30, through: 22 * 60, by: 30).map { $0 }
    }

    private func availabilityTimeMenu(
        text: String,
        options: [Int],
        selectedMinutes: Int,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { minutes in
                Button {
                    onSelect(minutes)
                } label: {
                    if minutes == selectedMinutes {
                        Label(timeText(for: minutes), systemImage: "checkmark")
                    } else {
                        Text(timeText(for: minutes))
                    }
                }
            }
        } label: {
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color(uiColor: .systemBlue))
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
    }

    private var excludedTimeMenu: some View {
        Menu {
            ForEach(ExcludedTimePreset.allCases) { preset in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        excludedTimeRule = preset.rule
                    }
                } label: {
                    if preset.rule == excludedTimeRule {
                        Label(preset.menuTitle, systemImage: "checkmark")
                    } else {
                        Text(preset.menuTitle)
                    }
                }
            }

            Divider()

            Button {
                isCustomExcludedTimePresented = true
            } label: {
                Label("직접 추가...", systemImage: "plus")
            }
        } label: {
            Text(excludedTimeRule.rowText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBlue))
                .lineLimit(1)
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
    }

    private func setAvailabilityStart(_ minutes: Int) {
        withAnimation(.easeInOut(duration: 0.16)) {
            availabilityStartMinutes = minutes

            if availabilityEndMinutes <= minutes {
                availabilityEndMinutes = min(minutes + 60, 22 * 60)
            }
        }
    }

    private func setAvailabilityEnd(_ minutes: Int) {
        withAnimation(.easeInOut(duration: 0.16)) {
            availabilityEndMinutes = max(minutes, availabilityStartMinutes + 30)
        }
    }

    private func moveToStep(_ step: CreateMeetingStep) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            if step == .info {
                hasVisitedInfoStep = true
            }

            currentStep = step
        }
    }

    private func timeText(for minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func candidateDates(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: max(startDate, endDate))
        var offset = 0

        while true {
            guard let date = calendar.date(byAdding: .day, value: offset, to: normalizedStartDate), date <= normalizedEndDate else {
                break
            }

            dates.append(date)

            offset += 1
        }

        return dates
    }

    private func shortDateText(for date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private func fullDateText(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월 \(components.day ?? 0)일 \(weekdayText(for: date))"
    }

    private func shortWeekdayDateText(for date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)월 \(components.day ?? 0)일 (\(shortWeekdayText(for: date)))"
    }

    private func weekdayText(for date: Date) -> String {
        let symbols = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
        let index = max(calendar.component(.weekday, from: date) - 1, 0)
        return symbols[min(index, symbols.count - 1)]
    }

    private func shortWeekdayText(for date: Date) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(calendar.component(.weekday, from: date) - 1, 0)
        return symbols[min(index, symbols.count - 1)]
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private var sanitizedMembers: [MeetingMemberDraft] {
        members.compactMap { member in
            let name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let role = member.role.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else {
                return nil
            }

            return MeetingMemberDraft(
                id: member.id,
                name: name,
                role: role,
                isRequired: member.isRequired,
                colorIndex: member.colorIndex
            )
        }
    }

    private func removeMember(_ member: MeetingMemberDraft) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            members.removeAll { $0.id == member.id }
        }
    }

    private func isRequiredInputComplete(for step: CreateMeetingStep) -> Bool {
        switch step {
        case .schedule:
            return isScheduleComplete
        case .info:
            return isInfoComplete
        case .participants:
            return isParticipantsComplete
        }
    }

    private var isScheduleComplete: Bool {
        guard let startDate, let endDate else {
            return false
        }

        return !calendar.isDate(startDate, inSameDayAs: endDate)
            && !candidateDates(from: startDate, to: endDate).isEmpty
    }

    private var isInfoComplete: Bool {
        hasVisitedInfoStep && isMeetingInfoComplete(meetingInfo)
    }

    private var isParticipantsComplete: Bool {
        sanitizedMembers.count == maxInviteeCount
    }

    private var canSubmit: Bool {
        isScheduleComplete && isInfoComplete && isParticipantsComplete
    }

    private func isStepAccessible(_ step: CreateMeetingStep) -> Bool {
        switch step {
        case .schedule:
            return true
        case .info:
            return isScheduleComplete
        case .participants:
            return isScheduleComplete && isInfoComplete
        }
    }

    private func submit() {
        guard canSubmit, let startDate, let endDate else {
            return
        }

        let draft = MeetingDraft(
            title: sanitizedTitle(for: meetingInfo).isEmpty ? "새 회의" : sanitizedTitle(for: meetingInfo),
            detail: meetingInfo.detail,
            sectionName: meetingInfo.sectionName,
            iconName: meetingInfo.iconName,
            meetingMode: meetingInfo.meetingMode,
            location: meetingInfo.location,
            startDate: startDate,
            endDate: endDate,
            availabilityWindowText: availabilityWindowText,
            durationText: meetingDurationText,
            excludedTimeText: excludedTimeText,
            excludedTimeRule: excludedTimeRule,
            members: sanitizedMembers
        )

        onCreate([draft])
    }

    private func addCalendarSection() {
        let trimmedName = newSectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        if !calendarSections.contains(trimmedName) {
            calendarSections.append(trimmedName)
        }

        meetingInfo.sectionName = trimmedName
        newSectionName = ""
    }

    private func participantIndex(for id: String) -> Int {
        members.firstIndex { $0.id == id } ?? 0
    }

    private func isMeetingInfoComplete(_ info: MeetingInfoDraft) -> Bool {
        let hasRequiredLocation = info.meetingMode == .online || !sanitizedLocation(for: info).isEmpty
        return !sanitizedTitle(for: info).isEmpty
            && !sanitizedDetail(for: info).isEmpty
            && hasRequiredLocation
            && !info.sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sanitizedTitle(for info: MeetingInfoDraft) -> String {
        info.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedDetail(for info: MeetingInfoDraft) -> String {
        info.detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedLocation(for info: MeetingInfoDraft) -> String {
        info.location.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CreateMeetingLayout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 28
    static let headerContentSpacing: CGFloat = 10
    static let contentSpacing: CGFloat = 12
    static let rowHeight: CGFloat = 52
    static let summaryRowHeight: CGFloat = 64
    static let participantRowHeight: CGFloat = 64
    static let cardHeaderHeight: CGFloat = 40
    static let cardDividerSpacing: CGFloat = 12
    static let actionButtonHeight: CGFloat = 40
    static let infoHeaderDividerTopSpacing: CGFloat = cardDividerSpacing
    static let cardPadding: CGFloat = 14
    static let cardContentPadding: CGFloat = cardPadding
    static let cardCornerRadius: CGFloat = 16
    static let headerListRowInsets = EdgeInsets(
        top: topInset,
        leading: horizontalInset,
        bottom: headerContentSpacing / 2,
        trailing: horizontalInset
    )
    static let contentListRowInsets = EdgeInsets(
        top: headerContentSpacing / 2,
        leading: horizontalInset,
        bottom: contentSpacing / 2,
        trailing: horizontalInset
    )
    static let singleContentListRowInsets = EdgeInsets(
        top: headerContentSpacing / 2,
        leading: horizontalInset,
        bottom: bottomInset,
        trailing: horizontalInset
    )
    static let footerListRowInsets = EdgeInsets(
        top: contentSpacing / 2,
        leading: horizontalInset,
        bottom: bottomInset,
        trailing: horizontalInset
    )

    static func participantCardRowInsets(isFirst: Bool, isLast: Bool) -> EdgeInsets {
        EdgeInsets(
            top: isFirst ? contentListRowInsets.top : 0,
            leading: horizontalInset,
            bottom: isLast ? contentListRowInsets.bottom : 0,
            trailing: horizontalInset
        )
    }
}

enum CreateMeetingStep: Int, CaseIterable, Identifiable {
    case schedule
    case info
    case participants

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .schedule:
            return "일정"
        case .info:
            return "정보"
        case .participants:
            return "참석자"
        }
    }

    var sectionTitle: String {
        switch self {
        case .schedule:
            return "후보 일정"
        case .info:
            return "회의 정보"
        case .participants:
            return "참석자"
        }
    }
}

struct CreateMeetingStepBar: View {
    let currentStep: CreateMeetingStep
    let isStepComplete: (CreateMeetingStep) -> Bool
    let isStepAccessible: (CreateMeetingStep) -> Bool
    let onSelect: (CreateMeetingStep) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(CreateMeetingStep.allCases) { step in
                    Button {
                        onSelect(step)
                    } label: {
                        CreateMeetingStepChip(
                            title: step.title,
                            isSelected: step == currentStep,
                            isCompleted: isStepComplete(step),
                            isAccessible: isStepAccessible(step),
                            showsCompletionIcon: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isStepAccessible(step))
                }
            }
            .padding(.horizontal, CreateMeetingLayout.horizontalInset)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct CreateMeetingStepChip: View {
    let title: String
    let isSelected: Bool
    let isCompleted: Bool
    let isAccessible: Bool
    let showsCompletionIcon: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            if isCompleted && showsCompletionIcon {
                Image(systemName: "checkmark.circle.fill")
                    .pillChipIcon(color: foregroundStyle, size: 12, frame: 14)
            }
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(backgroundStyle, in: Capsule())
        .overlay {
            Capsule()
                .stroke(isCompleted && !isSelected ? Color(uiColor: .separator) : Color.clear, lineWidth: 0.7)
        }
    }

    private var backgroundStyle: Color {
        if isSelected {
            return .primary
        }

        return Color(uiColor: isCompleted ? .systemBackground : .secondarySystemGroupedBackground)
    }

    private var foregroundStyle: Color {
        if isSelected {
            return .white
        }

        return Color(uiColor: isAccessible ? .secondaryLabel : .tertiaryLabel)
    }
}

struct CurrentStepHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .frame(height: 32, alignment: .center)
    }
}

struct DateRangeCalendarPicker: View {
    @Binding var displayedMonth: Date
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(monthTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(rangeTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    monthButton(systemName: "chevron.left") {
                        moveMonth(by: -1)
                    }

                    monthButton(systemName: "chevron.right") {
                        moveMonth(by: 1)
                    }
                }
            }

            VStack(spacing: 10) {
                LazyVGrid(columns: calendarColumns, spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, weekday in
                        Text(weekday)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(index == 0 || index == 6 ? Color(uiColor: .tertiaryLabel) : Color(uiColor: .secondaryLabel))
                            .frame(maxWidth: .infinity)
                        .frame(height: 24)
                    }
                }

                LazyVGrid(columns: calendarColumns, spacing: 4) {
                    ForEach(monthDays) { day in
                        Button {
                            select(day.date)
                        } label: {
                            DateRangeDayCell(
                                day: calendar.component(.day, from: day.date),
                                isCurrentMonth: day.isCurrentMonth,
                                isStart: isStart(day.date),
                                isEnd: isEnd(day.date),
                                isInRange: isInRange(day.date),
                                isSingleDayRange: isSingleDayRange,
                                isWeekStart: isWeekStart(day.date),
                                isWeekEnd: isWeekEnd(day.date),
                                continuesFromPreviousWeek: continuesFromPreviousWeek(day.date),
                                continuesToNextWeek: continuesToNextWeek(day.date),
                                isWeekend: isWeekend(day.date)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .id(monthIdentifier)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: monthIdentifier)
            .clipped()
        }
        .padding(CreateMeetingLayout.cardPadding)
        .contentShape(Rectangle())
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
        .simultaneousGesture(monthSwipeGesture)
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 7)
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 2026)년 \(components.month ?? 7)월"
    }

    private var monthIdentifier: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private var rangeTitle: String {
        guard let startDate else {
            return "일정을 선택하세요"
        }

        guard let endDate else {
            return "\(shortDateText(for: startDate))부터 종료일 선택"
        }

        let firstDate = min(startDate, endDate)
        let lastDate = max(startDate, endDate)

        if calendar.isDate(firstDate, inSameDayAs: lastDate) {
            return "\(shortDateText(for: firstDate)) 선택됨"
        }

        return "\(shortDateText(for: firstDate)) - \(shortDateText(for: lastDate))"
    }

    private var isSingleDayRange: Bool {
        guard let startDate, let endDate else {
            return true
        }

        return calendar.isDate(startDate, inSameDayAs: endDate)
    }

    private var monthDays: [CalendarDisplayDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstVisibleDate = calendar.date(byAdding: .day, value: -leadingDayCount(for: monthInterval.start), to: monthInterval.start)
        else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstVisibleDate) else {
                return nil
            }

            return CalendarDisplayDay(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
            )
        }
    }

    private func leadingDayCount(for date: Date) -> Int {
        let firstWeekday = calendar.component(.weekday, from: date)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    private func select(_ date: Date) {
        let tappedDate = calendar.startOfDay(for: date)

        guard let startDate else {
            withAnimation(.bouncy(duration: 0.42, extraBounce: 0.16)) {
                self.startDate = tappedDate
                self.endDate = nil
            }

            return
        }

        guard let endDate else {
            withAnimation(.bouncy(duration: 0.42, extraBounce: 0.16)) {
                if tappedDate < calendar.startOfDay(for: startDate) {
                    self.startDate = tappedDate
                    self.endDate = startDate
                } else if calendar.isDate(tappedDate, inSameDayAs: startDate) {
                    self.startDate = tappedDate
                    self.endDate = nil
                } else {
                    self.endDate = tappedDate
                }
            }

            return
        }

        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)

        withAnimation(.bouncy(duration: 0.42, extraBounce: 0.16)) {
            if !calendar.isDate(normalizedStartDate, inSameDayAs: normalizedEndDate) {
                self.startDate = tappedDate
                self.endDate = nil
            } else if tappedDate < normalizedStartDate {
                self.startDate = tappedDate
                self.endDate = normalizedStartDate
            } else {
                self.endDate = tappedDate
            }
        }
    }

    private func moveMonth(by value: Int) {
        guard
            let candidateMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth),
            let monthStart = calendar.dateInterval(of: .month, for: candidateMonth)?.start
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonth = monthStart
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height

                guard abs(width) > 56, abs(width) > abs(height) * 1.25 else {
                    return
                }

                moveMonth(by: width < 0 ? 1 : -1)
            }
    }

    private func isStart(_ date: Date) -> Bool {
        guard let startDate else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: startDate)
    }

    private func isEnd(_ date: Date) -> Bool {
        guard let endDate else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: endDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        guard let startDate, let endDate else {
            return false
        }

        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStartDate = calendar.startOfDay(for: min(startDate, endDate))
        let normalizedEndDate = calendar.startOfDay(for: max(startDate, endDate))
        return normalizedDate >= normalizedStartDate && normalizedDate <= normalizedEndDate
    }

    private func isWeekStart(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == calendar.firstWeekday
    }

    private func isWeekEnd(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == ((calendar.firstWeekday + 5) % 7) + 1
    }

    private func continuesFromPreviousWeek(_ date: Date) -> Bool {
        guard isWeekStart(date), let previousDate = calendar.date(byAdding: .day, value: -1, to: date) else {
            return false
        }

        return isInRange(previousDate)
    }

    private func continuesToNextWeek(_ date: Date) -> Bool {
        guard isWeekEnd(date), let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }

        return isInRange(nextDate)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func shortDateText(for date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private var weekdaySymbols: [String] {
        ["일", "월", "화", "수", "목", "금", "토"]
    }
}

struct DateRangeDayCell: View {
    let day: Int
    let isCurrentMonth: Bool
    let isStart: Bool
    let isEnd: Bool
    let isInRange: Bool
    let isSingleDayRange: Bool
    let isWeekStart: Bool
    let isWeekEnd: Bool
    let continuesFromPreviousWeek: Bool
    let continuesToNextWeek: Bool
    let isWeekend: Bool

    var body: some View {
        ZStack {
            rangeConnector

            Text("\(day)")
                .font(.body.weight(isEndpoint ? .semibold : .regular))
                .foregroundStyle(foregroundStyle)
                .frame(width: 34, height: 34)
                .background(isEndpoint ? selectionColor : Color.clear, in: Circle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rangeConnector: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if isInRange && !isSingleDayRange {
                    if isStart {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: 34)
                        }
                    } else if isEnd {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: 34)
                            Spacer(minLength: 0)
                        }
                    } else {
                        rangeSurface
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isInRange && !isSingleDayRange ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: isInRange)
        }
    }

    @ViewBuilder
    private var rangeSurface: some View {
        if isWeekStart || isWeekEnd {
            UnevenRoundedRectangle(cornerRadii: rangeCornerRadii, style: .continuous)
                .fill(rangeColor)
                .frame(height: 34)
        } else {
            Rectangle()
                .fill(rangeColor)
                .frame(height: 34)
        }
    }

    private var rangeCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: shouldRoundLeading ? 17 : 0,
            bottomLeading: shouldRoundLeading ? 17 : 0,
            bottomTrailing: shouldRoundTrailing ? 17 : 0,
            topTrailing: shouldRoundTrailing ? 17 : 0
        )
    }

    private var shouldRoundLeading: Bool {
        isWeekStart && !continuesFromPreviousWeek
    }

    private var shouldRoundTrailing: Bool {
        isWeekEnd && !continuesToNextWeek
    }

    private var rangeColor: Color {
        selectionColor.opacity(0.14)
    }

    private var selectionColor: Color {
        Color(uiColor: .systemBlue)
    }

    private var isEndpoint: Bool {
        isStart || isEnd
    }

    private var foregroundStyle: Color {
        if isEndpoint {
            return .white
        }

        if !isCurrentMonth {
            return Color(uiColor: .tertiaryLabel)
        }

        return isWeekend ? Color(uiColor: .secondaryLabel) : .primary
    }
}

struct ReviewCandidateCalendarWidget: View {
    let displayedMonth: Date
    let startDate: Date?
    let endDate: Date?
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }

            VStack(spacing: 5) {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, weekday in
                        Text(weekday)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index == 0 || index == 6 ? Color(uiColor: .tertiaryLabel) : Color(uiColor: .secondaryLabel))
                            .frame(maxWidth: .infinity)
                            .frame(height: 16)
                    }
                }

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(monthDays) { day in
                        MiniRangeDayCell(
                            day: calendar.component(.day, from: day.date),
                            isCurrentMonth: day.isCurrentMonth,
                            isStart: isStart(day.date),
                            isEnd: isEnd(day.date),
                            isInRange: isInRange(day.date),
                            isSingleDayRange: isSingleDayRange,
                            isWeekStart: isWeekStart(day.date),
                            isWeekEnd: isWeekEnd(day.date),
                            continuesFromPreviousWeek: continuesFromPreviousWeek(day.date),
                            continuesToNextWeek: continuesToNextWeek(day.date),
                            isWeekend: isWeekend(day.date)
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 7)
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.month ?? 0)월"
    }

    private var monthDays: [CalendarDisplayDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstVisibleDate = calendar.date(byAdding: .day, value: -leadingDayCount(for: monthInterval.start), to: monthInterval.start)
        else {
            return []
        }

        return (0..<(visibleWeekCount * 7)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstVisibleDate) else {
                return nil
            }

            return CalendarDisplayDay(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
            )
        }
    }

    private var visibleWeekCount: Int {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let lastMonthDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)
        else {
            return 5
        }

        let leadingDays = leadingDayCount(for: monthInterval.start)
        let dayCount = calendar.component(.day, from: lastMonthDay)
        return max(5, Int(ceil(Double(leadingDays + dayCount) / 7.0)))
    }

    private var isSingleDayRange: Bool {
        guard let startDate, let endDate else {
            return true
        }

        return calendar.isDate(startDate, inSameDayAs: endDate)
    }

    private func leadingDayCount(for date: Date) -> Int {
        let firstWeekday = calendar.component(.weekday, from: date)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    private func isStart(_ date: Date) -> Bool {
        guard let startDate else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: startDate)
    }

    private func isEnd(_ date: Date) -> Bool {
        guard let endDate else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: endDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        guard let startDate, let endDate else {
            return false
        }

        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStartDate = calendar.startOfDay(for: min(startDate, endDate))
        let normalizedEndDate = calendar.startOfDay(for: max(startDate, endDate))
        return normalizedDate >= normalizedStartDate && normalizedDate <= normalizedEndDate
    }

    private func isWeekStart(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == calendar.firstWeekday
    }

    private func isWeekEnd(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == ((calendar.firstWeekday + 5) % 7) + 1
    }

    private func continuesFromPreviousWeek(_ date: Date) -> Bool {
        guard isWeekStart(date), let previousDate = calendar.date(byAdding: .day, value: -1, to: date) else {
            return false
        }

        return isInRange(previousDate)
    }

    private func continuesToNextWeek(_ date: Date) -> Bool {
        guard isWeekEnd(date), let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }

        return isInRange(nextDate)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private var weekdaySymbols: [String] {
        ["일", "월", "화", "수", "목", "금", "토"]
    }
}

struct MiniRangeDayCell: View {
    let day: Int
    let isCurrentMonth: Bool
    let isStart: Bool
    let isEnd: Bool
    let isInRange: Bool
    let isSingleDayRange: Bool
    let isWeekStart: Bool
    let isWeekEnd: Bool
    let continuesFromPreviousWeek: Bool
    let continuesToNextWeek: Bool
    let isWeekend: Bool

    var body: some View {
        ZStack {
            rangeConnector

            Text("\(day)")
                .font(.system(size: 12, weight: isEndpoint ? .semibold : .semibold))
                .foregroundStyle(foregroundStyle)
                .monospacedDigit()
                .frame(width: metric, height: metric)
                .background(isEndpoint ? selectionColor : Color.clear, in: Circle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: metric)
    }

    @ViewBuilder
    private var rangeConnector: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if isInRange && !isSingleDayRange {
                    if isStart {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: metric)
                        }
                    } else if isEnd {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: metric)
                            Spacer(minLength: 0)
                        }
                    } else {
                        rangeSurface
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isInRange && !isSingleDayRange ? 1 : 0)
        }
    }

    @ViewBuilder
    private var rangeSurface: some View {
        if isWeekStart || isWeekEnd {
            UnevenRoundedRectangle(cornerRadii: rangeCornerRadii, style: .continuous)
                .fill(rangeColor)
                .frame(height: metric)
        } else {
            Rectangle()
                .fill(rangeColor)
                .frame(height: metric)
        }
    }

    private var rangeCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: shouldRoundLeading ? radius : 0,
            bottomLeading: shouldRoundLeading ? radius : 0,
            bottomTrailing: shouldRoundTrailing ? radius : 0,
            topTrailing: shouldRoundTrailing ? radius : 0
        )
    }

    private var shouldRoundLeading: Bool {
        isWeekStart && !continuesFromPreviousWeek
    }

    private var shouldRoundTrailing: Bool {
        isWeekEnd && !continuesToNextWeek
    }

    private var rangeColor: Color {
        selectionColor.opacity(0.14)
    }

    private var selectionColor: Color {
        Color(uiColor: .systemBlue)
    }

    private var metric: CGFloat {
        19
    }

    private var radius: CGFloat {
        metric / 2
    }

    private var isEndpoint: Bool {
        isStart || isEnd
    }

    private var foregroundStyle: Color {
        if isEndpoint {
            return .white
        }

        if !isCurrentMonth {
            return Color(uiColor: .tertiaryLabel)
        }

        return isInRange ? .primary : Color(uiColor: .secondaryLabel)
    }
}

struct ReviewMeetingInfoSquareCard: View {
    let title: String
    let tint: Color
    let mode: String
    let location: String
    let duration: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                ReviewMeetingInfoMiniLine(text: duration, systemImage: "clock.fill", tint: Color(uiColor: .systemOrange))
                ReviewMeetingInfoMiniLine(text: mode, systemImage: mode == "온라인" ? "video.fill" : "person.2.fill", tint: Color(uiColor: .systemBlue))
                ReviewMeetingInfoMiniLine(text: location, systemImage: "mappin.circle.fill", tint: tint)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
    }
}

struct ReviewMeetingInfoMiniLine: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14, height: 14)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(tint.opacity(0.11), in: Capsule())
    }
}

struct ReviewScheduleOverviewCard: View {
    let range: String
    let timeWindow: String
    let duration: String
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReviewCardHeader(title: "후보 기간")

            VStack(alignment: .leading, spacing: 6) {
                Text(range)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("팀원에게 공유할 일정 범위")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ReviewChipRow {
                ReviewMetaPill(text: timeWindow, systemImage: "clock")
                ReviewMetaPill(text: duration, systemImage: "hourglass")
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewCompactMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewMeetingOverviewCard<Content: View>: View {
    let onEdit: () -> Void
    let content: Content

    init(onEdit: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onEdit = onEdit
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReviewCardHeader(title: "회의 정보")

            VStack(spacing: 10) {
                content
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewMeetingTile: View {
    let index: Int
    let title: String
    let mode: String
    let section: String
    let sectionTint: Color
    let location: String
    let detail: String
    let onEdit: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReviewCardHeader(title: "회의 \(index)")

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            ReviewChipRow {
                ReviewColorPill(text: section, tint: sectionTint)
                ReviewMetaPill(text: mode, systemImage: mode == "온라인" ? "video" : "person.2")
                ReviewMetaPill(text: location, systemImage: "mappin.and.ellipse")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ReviewDetailLine(title: "내용", value: detail, systemImage: "text.alignleft", lineLimit: 3)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewInviteeListCard: View {
    let totalCount: Int
    let invitedCount: Int
    let requiredCount: Int
    let optionalCount: Int
    let members: [MeetingMemberDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("초대 명단")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("주최자 포함 총 \(totalCount)명 · 초대 \(invitedCount)명")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                AvatarStack(names: members.map(\.name), maxVisible: 5)
            }

            HStack(spacing: 8) {
                Text(collapsedMemberText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
    }

    private var collapsedMemberText: String {
        guard !members.isEmpty else {
            return "아직 초대된 참석자가 없습니다"
        }

        let names = members.prefix(3).map(\.name).joined(separator: ", ")
        guard members.count > 3 else {
            return names
        }

        return "\(names) 외 \(members.count - 3)명"
    }
}

struct ReviewInviteeDetailCard: View {
    let totalCount: Int
    let invitedCount: Int
    let requiredCount: Int
    let optionalCount: Int
    let members: [MeetingMemberDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("참석자")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("주최자 1명 · 초대 \(invitedCount)/\(max(totalCount - 1, 0))명")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ReviewChipRow {
                ReviewMetaPill(text: "총 \(totalCount)명", systemImage: "person.2.fill", tint: Color(uiColor: .systemBlue))
                ReviewMetaPill(text: "필참 \(requiredCount)", systemImage: "checkmark.circle.fill", tint: Color(uiColor: .systemGreen))
                ReviewMetaPill(text: "선택 \(optionalCount)", systemImage: "circle.fill", tint: Color(uiColor: .systemGray))
            }

            VStack(spacing: 0) {
                ReviewInviteeDetailRow(
                    initial: "나",
                    name: "나",
                    role: "디자인 팀 팀장",
                    badge: "주최자",
                    tint: Color(uiColor: .systemIndigo),
                    badgeTint: Color(uiColor: .systemBlue)
                )

                if !members.isEmpty {
                    ReviewMeetingInfoDivider()

                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        ReviewInviteeDetailRow(
                            initial: member.initial,
                            name: member.name,
                            role: member.role,
                            badge: member.isRequired ? "필참" : "선택",
                            tint: AvatarStack.colors[member.colorIndex % AvatarStack.colors.count],
                            badgeTint: member.isRequired ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray)
                        )

                        if index < members.count - 1 {
                            ReviewMeetingInfoDivider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewInviteeDetailRow: View {
    let initial: String
    let name: String
    let role: String
    let badge: String
    let tint: Color
    let badgeTint: Color

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(name: name, fallback: initial, size: 34, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(role)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(badge)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(badgeTint)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(badgeTint.opacity(0.1), in: Capsule())
        }
        .frame(height: 56)
    }
}

struct ReviewCandidateDateRow: Hashable {
    let dateText: String
    let weekday: String
    let isWeekend: Bool
}

struct ReviewPressableCard<Content: View>: View {
    let action: () -> Void
    let content: Content

    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.content = label()
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    isPressed = false
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                action()
            }
        } label: {
            content
                .scaleEffect(isPressed ? 0.965 : 1)
                .opacity(isPressed ? 0.96 : 1)
                .contentShape(RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(
            .spring(response: 0.24, dampingFraction: 0.78),
            value: isPressed
        )
    }
}

struct ReviewDetailSummaryCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.12), in: Circle())

                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 46)
            }

            ReviewChipRow {
                content
            }
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewDetailSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewMeetingInfoDetailCard: View {
    let title: String
    let detail: String
    let sectionName: String
    let iconName: String
    let mode: String
    let location: String
    let duration: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MeetingIconStyle.tint(for: iconName))
                    .frame(width: 40, height: 40)
                    .background(MeetingIconStyle.tint(for: iconName).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                ReviewMeetingInfoMetaRow(
                    title: "캘린더",
                    value: sectionName,
                    systemImage: "calendar"
                )

                ReviewMeetingInfoDivider()

                ReviewMeetingInfoMetaRow(
                    title: "방식",
                    value: mode,
                    systemImage: mode == "온라인" ? "video.fill" : "person.2.fill"
                )

                ReviewMeetingInfoDivider()

                ReviewMeetingInfoMetaRow(
                    title: "장소",
                    value: location,
                    systemImage: "mappin.circle.fill"
                )

                ReviewMeetingInfoDivider()

                ReviewMeetingInfoMetaRow(
                    title: "시간",
                    value: duration,
                    systemImage: "clock.fill"
                )
            }
            .padding(.vertical, 2)

            Divider()
                .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .frame(width: 16, height: 16)

                    Text("내용")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(detail.isEmpty ? "회의 내용이 입력되지 않았습니다." : detail)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 0.8)
                    }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewMeetingInfoMetaRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .frame(width: 16, height: 16)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: CreateMeetingLayout.rowHeight)
    }
}

struct ReviewMeetingInfoDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 28)
    }
}

struct ReviewCardHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)
        }
    }
}

struct ReviewChipRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
        }
        .scrollClipDisabled()
    }
}

struct ReviewMetaPill: View {
    let text: String
    let systemImage: String
    var tint: Color?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .pillChipIcon(color: contentColor, size: 11, frame: 13)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(contentColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(pillBackground, in: Capsule())
    }

    private var pillBackground: Color {
        guard let tint else {
            return Color(uiColor: .systemBackground)
        }

        return tint.opacity(0.11)
    }

    private var contentColor: Color {
        tint ?? Color(uiColor: .secondaryLabel)
    }
}

struct ReviewColorPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color(uiColor: .systemBackground), in: Capsule())
    }
}

struct ReviewDisclosureButton: View {
    let title: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(Color(uiColor: .systemBlue))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ReviewDetailLine: View {
    let title: String
    let value: String
    let systemImage: String
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: lineLimit == 1 ? .center : .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ReviewCompactParticipantRow: View {
    let member: MeetingMemberDraft

    var body: some View {
        HStack(spacing: 10) {
            ProfileAvatar(
                name: member.name,
                fallback: member.initial,
                size: 28,
                tint: AvatarStack.colors[member.colorIndex % AvatarStack.colors.count]
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(member.role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Text(member.isRequired ? "필참" : "선택")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(member.isRequired ? Color(uiColor: .systemBlue) : .secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ReviewSectionCard<Content: View>: View {
    let title: String
    let onEdit: () -> Void
    let content: Content

    init(
        title: String,
        onEdit: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onEdit = onEdit
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)
            }
            .frame(height: CreateMeetingLayout.cardHeaderHeight)

            Divider()

            content
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct ReviewInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(height: CreateMeetingLayout.rowHeight)
    }
}

struct ReviewMeetingSummary: View {
    let index: Int
    let title: String
    let mode: String
    let section: String
    let sectionTint: Color
    let location: String
    let detail: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("회의 \(index)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(mode)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            }
            .frame(height: CreateMeetingLayout.summaryRowHeight)

            ReviewDivider()

            ReviewCalendarTextRow(title: "캘린더", value: section, tint: sectionTint)
            ReviewDivider()
            ReviewTextRow(title: "장소", value: location)
            ReviewDivider()
            ReviewTextRow(title: "내용", value: detail, lineLimit: 2)
        }
    }
}

struct ReviewCalendarTextRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)

                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CreateMeetingLayout.rowHeight, alignment: .center)
    }
}

struct ReviewTextRow: View {
    let title: String
    let value: String
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: lineLimit == 1 ? .center : .top, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CreateMeetingLayout.rowHeight, alignment: .center)
        .padding(.vertical, lineLimit == 1 ? 0 : 8)
    }
}

struct ReviewParticipantRow: View {
    let member: MeetingMemberDraft

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(
                name: member.name,
                fallback: member.initial,
                size: 32,
                tint: AvatarStack.colors[member.colorIndex % AvatarStack.colors.count]
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(member.role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(member.isRequired ? "필참" : "선택")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(member.isRequired ? Color(uiColor: .systemBlue) : .secondary)
        }
        .frame(height: CreateMeetingLayout.participantRowHeight)
    }
}

struct ReviewDivider: View {
    var body: some View {
        Divider()
    }
}

struct ReviewSummaryBlock: View {
    let title: String
    let chips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            FlowChipRow(chips: chips)
        }
    }
}

struct FlowChipRow: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                }
            }
        }
        .scrollClipDisabled()
    }
}

struct ParticipantLimitSummaryRow: View {
    @Binding var totalParticipantCount: Int
    let selectedInviteeCount: Int
    let maxInviteeCount: Int
    let participantRange: ClosedRange<Int>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("참석 인원")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("주최자 1명 · 초대 \(selectedInviteeCount)/\(maxInviteeCount)명")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedInviteeCount == maxInviteeCount ? Color(uiColor: .systemBlue) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(Array(participantRange), id: \.self) { count in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            totalParticipantCount = count
                        }
                    } label: {
                        if count == totalParticipantCount {
                            Label("총 \(count)명", systemImage: "checkmark")
                        } else {
                            Text("총 \(count)명")
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("총 \(totalParticipantCount)명")
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(Color(uiColor: .systemBlue))
                .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
        }
        .frame(height: CreateMeetingLayout.summaryRowHeight)
    }
}

struct CreateMeetingAddActionButton: View {
    let title: String
    let isDisabled: Bool

    init(title: String, isDisabled: Bool = false) {
        self.title = title
        self.isDisabled = isDisabled
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(isDisabled ? Color(uiColor: .tertiaryLabel) : Color(uiColor: .systemBlue))
        .frame(maxWidth: .infinity)
        .frame(height: CreateMeetingLayout.actionButtonHeight)
        .contentShape(Rectangle())
    }
}

struct HostParticipantRow: View {
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(name: "나", fallback: "나", size: 32, tint: Color(uiColor: .systemIndigo))

            VStack(alignment: .leading, spacing: 3) {
                Text("나")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("디자인 팀 팀장")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("주최자")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBlue))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(uiColor: .systemBlue).opacity(0.1), in: Capsule())
        }
        .frame(height: CreateMeetingLayout.participantRowHeight)
        .padding(.horizontal, CreateMeetingLayout.cardContentPadding)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, CreateMeetingLayout.cardContentPadding + 44)
                    .padding(.trailing, CreateMeetingLayout.cardContentPadding)
            }
        }
        .contentShape(Rectangle())
    }
}

struct SelectedParticipantRow: View {
    @Binding var member: MeetingMemberDraft
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(
                name: member.name,
                fallback: member.initial,
                size: 32,
                tint: AvatarStack.colors[member.colorIndex % AvatarStack.colors.count]
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(member.role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("참여 유형", selection: $member.isRequired) {
                Text("필참").tag(true)
                Text("선택").tag(false)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 116)
        }
        .frame(height: CreateMeetingLayout.participantRowHeight)
        .padding(.horizontal, CreateMeetingLayout.cardContentPadding)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, CreateMeetingLayout.cardContentPadding + 44)
                    .padding(.trailing, CreateMeetingLayout.cardContentPadding)
            }
        }
        .contentShape(Rectangle())
    }

}

struct ParticipantRowBackground: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? CreateMeetingLayout.cardCornerRadius : 0,
            bottomLeadingRadius: isLast ? CreateMeetingLayout.cardCornerRadius : 0,
            bottomTrailingRadius: isLast ? CreateMeetingLayout.cardCornerRadius : 0,
            topTrailingRadius: isFirst ? CreateMeetingLayout.cardCornerRadius : 0,
            style: .continuous
        )
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

struct ParticipantPickerSheet: View {
    let availableMembers: [TeamMember]
    let maxInviteeCount: Int
    @Binding var selectedMembers: [MeetingMemberDraft]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    Section("검색 결과") {
                        ForEach(filteredMembers) { member in
                            memberRow(member)
                        }
                    }
                } else {
                    if !recentMembers.isEmpty {
                        Section {
                            ForEach(recentMembers) { member in
                                memberRow(member)
                            }
                        } header: {
                            ParticipantPickerSectionHeader(
                                title: "최근 초대",
                                actionTitle: "모두 추가",
                                isDisabled: remainingInviteeSlots == 0 || selectableMembers(from: recentMembers).isEmpty,
                                action: {
                                    addAll(recentMembers)
                                }
                            )
                        }
                    }

                    ForEach(TeamCategory.allCases) { category in
                        let members = members(in: category)

                        if !members.isEmpty {
                            Section {
                                ForEach(members) { member in
                                    memberRow(member)
                                }
                            } header: {
                                ParticipantPickerSectionHeader(
                                    title: category.title,
                                    actionTitle: "모두 추가",
                                    isDisabled: remainingInviteeSlots == 0 || selectableMembers(from: members).isEmpty,
                                    action: {
                                        addAll(members)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("참석자 선택")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "이름 또는 역할 검색")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredMembers: [TeamMember] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSearchText.isEmpty else {
            return availableMembers
        }

        return availableMembers.filter { member in
            member.name.localizedCaseInsensitiveContains(trimmedSearchText)
                || member.role.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var recentMembers: [TeamMember] {
        availableMembers.filter(\.isRecent)
    }

    private var remainingInviteeSlots: Int {
        max(maxInviteeCount - selectedMembers.count, 0)
    }

    private func members(in category: TeamCategory) -> [TeamMember] {
        availableMembers.filter { $0.category == category }
    }

    private func memberRow(_ member: TeamMember) -> some View {
        let selected = isSelected(member)
        let isDisabled = !selected && remainingInviteeSlots == 0

        return Button {
            toggleMember(member)
        } label: {
            HStack(spacing: 12) {
                ProfileAvatar(
                    name: member.name,
                    fallback: member.initial,
                    size: 34,
                    tint: AvatarStack.colors[member.colorIndex % AvatarStack.colors.count]
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(member.role)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Color.primary : Color(uiColor: .tertiaryLabel))
            }
            .opacity(isDisabled ? 0.42 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .frame(minHeight: 50)
    }

    private func isSelected(_ member: TeamMember) -> Bool {
        selectedMembers.contains { $0.id == member.id }
    }

    private func toggleMember(_ member: TeamMember) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            if let index = selectedMembers.firstIndex(where: { $0.id == member.id }) {
                selectedMembers.remove(at: index)
            } else if remainingInviteeSlots > 0 {
                selectedMembers.append(MeetingMemberDraft(member: member))
            }
        }
    }

    private func addAll(_ members: [TeamMember]) {
        let newMembers = Array(selectableMembers(from: members).prefix(remainingInviteeSlots))

        guard !newMembers.isEmpty else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            selectedMembers.append(contentsOf: newMembers.map(MeetingMemberDraft.init(member:)))
        }
    }

    private func selectableMembers(from members: [TeamMember]) -> [TeamMember] {
        members.filter { member in
            !selectedMembers.contains { $0.id == member.id }
        }
    }
}

struct ParticipantPickerSectionHeader: View {
    let title: String
    let actionTitle: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button(actionTitle, action: action)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDisabled ? Color(uiColor: .tertiaryLabel) : Color(uiColor: .systemBlue))
                .buttonStyle(.plain)
                .disabled(isDisabled)
        }
        .frame(maxWidth: .infinity)
        .textCase(nil)
    }
}

enum MeetingInfoLayout {
    static let labelWidth: CGFloat = 70
    static let rowHeight: CGFloat = CreateMeetingLayout.rowHeight
    static let horizontalPadding: CGFloat = 0
    static let columnSpacing: CGFloat = 12
    static let dividerLeading: CGFloat = labelWidth + columnSpacing + horizontalPadding
}

struct MeetingInfoDraft: Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var sectionName: String
    var meetingMode: MeetingMode
    var location: String
    var iconName: String

    static func defaultDraft() -> MeetingInfoDraft {
        MeetingInfoDraft(
            id: UUID().uuidString,
            title: "디자인팀 주간 회의",
            detail: "이번 주 디자인 진행 상황을 공유합니다.",
            sectionName: "디자인팀",
            meetingMode: .offline,
            location: "디자인팀 회의실",
            iconName: "paintpalette.fill"
        )
    }

    static func emptyDraft(sectionName: String) -> MeetingInfoDraft {
        MeetingInfoDraft(
            id: UUID().uuidString,
            title: "",
            detail: "",
            sectionName: sectionName,
            meetingMode: .offline,
            location: "디자인팀 회의실",
            iconName: "person.2.fill"
        )
    }
}

enum MeetingInfoField: Hashable {
    case title(String)
    case location(String)
    case detail(String)
}

struct MeetingInfoCard: View {
    @Binding var info: MeetingInfoDraft

    let sections: [String]
    var focusedField: FocusState<MeetingInfoField?>.Binding
    let onSelectSection: (String) -> Void
    let onAddSection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                MeetingIconPickerButton(iconName: $info.iconName)

                TextField("회의명", text: $info.title, prompt: Text("회의명을 입력"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .textFieldStyle(.plain)
                    .textContentType(.none)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)
                    .focused(focusedField, equals: .title(info.id))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: CreateMeetingLayout.cardHeaderHeight)

            Divider()
                .padding(.top, CreateMeetingLayout.infoHeaderDividerTopSpacing)

            MeetingInfoCalendarRow(
                selectedSection: info.sectionName,
                sections: sections,
                onSelect: onSelectSection,
                onAdd: onAddSection
            )

            MeetingInfoDivider()

            MeetingModeRow(selection: $info.meetingMode)

            MeetingInfoDivider()

            MeetingInfoTextFieldRow(
                title: "장소",
                placeholder: "장소를 입력",
                text: $info.location,
                field: .location(info.id),
                focusedField: focusedField
            )

            MeetingInfoDivider()

            MeetingInfoDetailRow(
                text: $info.detail,
                field: .detail(info.id),
                focusedField: focusedField
            )
        }
        .padding(CreateMeetingLayout.cardContentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CreateMeetingLayout.cardCornerRadius, style: .continuous)
        )
    }
}

struct MeetingIconPickerButton: View {
    @Binding var iconName: String

    private let options = [
        "person.2.fill",
        "paintpalette.fill",
        "calendar.badge.clock",
        "bubble.left.and.bubble.right.fill",
        "lightbulb.fill",
        "checklist",
        "sparkles"
    ]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    iconName = option
                } label: {
                    if option == iconName {
                        Label(MeetingIconStyle.title(for: option), systemImage: "checkmark")
                    } else {
                        Label(MeetingIconStyle.title(for: option), systemImage: option)
                    }
                }
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MeetingIconStyle.tint(for: iconName))
                .frame(width: 36, height: 36)
                .background(MeetingIconStyle.tint(for: iconName).opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("회의 아이콘 선택")
    }
}

enum MeetingIconStyle {
    static func title(for iconName: String) -> String {
        switch iconName {
        case "person.2.fill":
            return "팀 회의"
        case "paintpalette.fill":
            return "디자인"
        case "calendar.badge.clock":
            return "일정"
        case "bubble.left.and.bubble.right.fill":
            return "논의"
        case "lightbulb.fill":
            return "아이디어"
        case "checklist":
            return "체크리스트"
        case "sparkles":
            return "워크숍"
        default:
            return "회의"
        }
    }

    static func tint(for iconName: String) -> Color {
        switch iconName {
        case "person.2.fill":
            return Color(uiColor: .systemBlue)
        case "paintpalette.fill":
            return Color(uiColor: .systemPurple)
        case "calendar.badge.clock":
            return Color(uiColor: .systemOrange)
        case "bubble.left.and.bubble.right.fill":
            return Color(uiColor: .systemTeal)
        case "lightbulb.fill":
            return Color(uiColor: .systemYellow)
        case "checklist":
            return Color(uiColor: .systemGreen)
        case "sparkles":
            return Color(uiColor: .systemPink)
        default:
            return Color(uiColor: .systemBlue)
        }
    }
}

struct MeetingInfoTextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let field: MeetingInfoField
    var focusedField: FocusState<MeetingInfoField?>.Binding

    var body: some View {
        HStack(alignment: .center, spacing: MeetingInfoLayout.columnSpacing) {
            MeetingInfoLabel(title, systemImage: "mappin.circle.fill")

            TextField(title, text: $text, prompt: Text(placeholder))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)
                .textFieldStyle(.plain)
                .textContentType(.none)
                .autocorrectionDisabled(true)
                .submitLabel(.next)
                .focused(focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, MeetingInfoLayout.horizontalPadding)
        .frame(height: MeetingInfoLayout.rowHeight)
    }
}

struct MeetingModeRow: View {
    @Binding var selection: MeetingMode

    var body: some View {
        HStack(alignment: .center, spacing: MeetingInfoLayout.columnSpacing) {
            MeetingInfoLabel("방식", systemImage: "person.2.fill")

            MeetingModeSegmentControl(selection: $selection)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, MeetingInfoLayout.horizontalPadding)
        .frame(height: MeetingInfoLayout.rowHeight)
    }
}

struct MeetingModeSegmentControl: View {
    @Binding var selection: MeetingMode

    var body: some View {
        Picker("방식", selection: $selection) {
            ForEach(MeetingMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 158)
    }
}

struct MeetingInfoCalendarRow: View {
    let selectedSection: String
    let sections: [String]
    let onSelect: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: MeetingInfoLayout.columnSpacing) {
            MeetingInfoLabel("캘린더", systemImage: "calendar")

            Menu {
                ForEach(sections, id: \.self) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        if section == selectedSection {
                            Label(section, systemImage: "checkmark")
                        } else {
                            Text(section)
                        }
                    }
                }

                Divider()

                Button(action: onAdd) {
                    Label("새 캘린더 추가", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedSection)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
        }
        .padding(.horizontal, MeetingInfoLayout.horizontalPadding)
        .frame(height: MeetingInfoLayout.rowHeight)
    }

}

enum CalendarSectionTint {
    static func color(for section: String) -> Color {
        switch section {
        case "디자인팀":
            return Color(uiColor: .systemPurple)
        case "제품팀":
            return Color(uiColor: .systemBlue)
        case "리서치":
            return Color(uiColor: .systemGreen)
        case "브랜드":
            return Color(uiColor: .systemOrange)
        default:
            return Color(uiColor: .systemGray)
        }
    }
}

struct MeetingInfoDetailRow: View {
    @Binding var text: String
    let field: MeetingInfoField
    var focusedField: FocusState<MeetingInfoField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MeetingInfoLabel("내용", systemImage: "text.alignleft")

            TextField(
                "내용",
                text: $text,
                prompt: Text("회의 목적이나 논의할 내용을 입력"),
                axis: .vertical
            )
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .textFieldStyle(.plain)
            .textContentType(.none)
            .autocorrectionDisabled(true)
            .lineLimit(4...6)
            .submitLabel(.done)
            .focused(focusedField, equals: field)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.32), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 5, y: 1)
        }
        .padding(.horizontal, MeetingInfoLayout.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 0)
    }
}

struct MeetingInfoLabel: View {
    let title: String
    var systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .frame(width: 16, height: 16)
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: MeetingInfoLayout.labelWidth, alignment: .leading)
    }
}

struct MeetingInfoDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, MeetingInfoLayout.dividerLeading)
    }
}

struct LabeledTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            TextField(title, text: $text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .textContentType(.none)
                .autocorrectionDisabled(true)
        }
        .padding(14)
        .frame(minHeight: 52)
    }
}

struct CustomExcludedTimeSheet: View {
    let initialRule: ExcludedTimeRule
    let onCancel: () -> Void
    let onSave: (ExcludedTimeRule) -> Void

    @State private var title: String
    @State private var startHour: Int
    @State private var endHour: Int

    init(
        initialRule: ExcludedTimeRule,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ExcludedTimeRule) -> Void
    ) {
        self.initialRule = initialRule
        self.onCancel = onCancel
        self.onSave = onSave

        _title = State(initialValue: initialRule.title)
        _startHour = State(initialValue: initialRule.startHour)
        _endHour = State(initialValue: initialRule.endHour)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Text("이름")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .leading)

                        TextField("제외 시간", text: $title)
                            .font(.system(size: 16, weight: .semibold))
                            .textContentType(.none)
                            .autocorrectionDisabled(true)
                    }
                    .frame(height: 44)

                    excludedTimeRow(title: "시작", selectedHour: startHour, options: startHourOptions) { hour in
                        startHour = hour

                        if endHour <= hour {
                            endHour = min(hour + 1, 18)
                        }
                    }

                    excludedTimeRow(title: "종료", selectedHour: endHour, options: endHourOptions) { hour in
                        endHour = max(hour, startHour + 1)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("제외 시간 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(
                            ExcludedTimeRule(
                                id: "custom-\(trimmedTitle)-\(startHour)-\(endHour)",
                                title: trimmedTitle,
                                startHour: startHour,
                                endHour: endHour,
                                isEnabled: true,
                                isCustom: true
                            )
                        )
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    private func excludedTimeRow(
        title: String,
        selectedHour: Int,
        options: [Int],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Spacer(minLength: 12)

            Menu {
                ForEach(options, id: \.self) { hour in
                    Button {
                        onSelect(hour)
                    } label: {
                        if hour == selectedHour {
                            Label(timeText(for: hour), systemImage: "checkmark")
                        } else {
                            Text(timeText(for: hour))
                        }
                    }
                }
            } label: {
                Text(timeText(for: selectedHour))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(uiColor: .systemBlue))
            }
            .menuOrder(.fixed)
        }
        .frame(height: 44)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && endHour > startHour
    }

    private var startHourOptions: [Int] {
        Array(9..<18)
    }

    private var endHourOptions: [Int] {
        Array((startHour + 1)...18)
    }

    private func timeText(for hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

struct MeetingDraft {
    let title: String
    let detail: String
    let sectionName: String
    let iconName: String
    let meetingMode: MeetingMode
    let location: String
    let startDate: Date
    let endDate: Date
    let availabilityWindowText: String
    let durationText: String
    let excludedTimeText: String
    let excludedTimeRule: ExcludedTimeRule
    let members: [MeetingMemberDraft]
}

struct ExcludedTimeRule: Equatable {
    let id: String
    let title: String
    let startHour: Int
    let endHour: Int
    let isEnabled: Bool
    let isCustom: Bool

    static let none = ExcludedTimeRule(id: "none", title: "없음", startHour: 0, endHour: 0, isEnabled: false, isCustom: false)
    static let breakfast = ExcludedTimeRule(id: "breakfast", title: "아침", startHour: 7, endHour: 9, isEnabled: true, isCustom: false)
    static let lunch = ExcludedTimeRule(id: "lunch", title: "점심시간", startHour: 12, endHour: 13, isEnabled: true, isCustom: false)
    static let dinner = ExcludedTimeRule(id: "dinner", title: "저녁시간", startHour: 18, endHour: 19, isEnabled: true, isCustom: false)
    static let customDefault = ExcludedTimeRule(id: "custom", title: "집중 시간", startHour: 15, endHour: 16, isEnabled: true, isCustom: true)

    var rowText: String {
        isEnabled ? title : "없음"
    }

    var summaryText: String {
        isEnabled ? "\(title) 제외" : "제외 없음"
    }

    var menuTitle: String {
        guard isEnabled else {
            return "없음"
        }

        return "\(title) \(timeText(for: startHour))-\(timeText(for: endHour))"
    }

    var blockTitle: String {
        isEnabled ? "\(title) 제외" : ""
    }

    func excludes(hour: Int, date: Date, calendar: Calendar) -> Bool {
        guard isEnabled, !isWeekend(date, calendar: calendar) else {
            return false
        }

        return (startHour..<endHour).contains(hour)
    }

    private func timeText(for hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

enum ExcludedTimePreset: String, CaseIterable, Identifiable {
    case none
    case breakfast
    case lunch
    case dinner

    var id: String {
        rawValue
    }

    var menuTitle: String {
        rule.menuTitle
    }

    var rule: ExcludedTimeRule {
        switch self {
        case .none:
            return .none
        case .breakfast:
            return .breakfast
        case .lunch:
            return .lunch
        case .dinner:
            return .dinner
        }
    }
}

enum MeetingMode: String, CaseIterable, Identifiable {
    case offline
    case online

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .offline:
            return "오프라인"
        case .online:
            return "온라인"
        }
    }
}

struct MeetingMemberDraft: Identifiable {
    let id: String
    var name: String
    var role: String
    var isRequired: Bool
    var colorIndex: Int

    init(id: String, name: String, role: String, isRequired: Bool, colorIndex: Int) {
        self.id = id
        self.name = name
        self.role = role
        self.isRequired = isRequired
        self.colorIndex = colorIndex
    }

    init(member: TeamMember) {
        id = member.id
        name = member.name
        role = member.role
        isRequired = true
        colorIndex = member.colorIndex
    }

    var initial: String {
        let roleText = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameText = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if !roleText.isEmpty {
            return roleText
                .filter { !$0.isWhitespace }
                .prefix(2)
                .map(String.init)
                .joined()
                .uppercased()
        }

        return nameText
            .prefix(1)
            .map(String.init)
            .joined()
    }
}

struct TeamMember: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let category: TeamCategory
    let isRecent: Bool
    let colorIndex: Int

    var initial: String {
        role
            .filter { !$0.isWhitespace }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
    }

    static let sampleMembers = [
        TeamMember(id: "member-minjun", name: "김민준", role: "PM", category: .product, isRecent: true, colorIndex: 0),
        TeamMember(id: "member-soyeon", name: "이서연", role: "Product Designer", category: .design, isRecent: true, colorIndex: 1),
        TeamMember(id: "member-yujin", name: "오유진", role: "UX Designer", category: .design, isRecent: false, colorIndex: 2),
        TeamMember(id: "member-seungah", name: "송승아", role: "UI Designer", category: .design, isRecent: false, colorIndex: 3),
        TeamMember(id: "member-doyoon", name: "박도윤", role: "FE", category: .engineering, isRecent: true, colorIndex: 2),
        TeamMember(id: "member-harin", name: "최하린", role: "BE", category: .engineering, isRecent: false, colorIndex: 3),
        TeamMember(id: "member-jaehyun", name: "윤재현", role: "iOS Developer", category: .engineering, isRecent: false, colorIndex: 0),
        TeamMember(id: "member-hyejin", name: "장혜진", role: "QA", category: .engineering, isRecent: false, colorIndex: 1),
        TeamMember(id: "member-jiwoo", name: "정지우", role: "UX Researcher", category: .research, isRecent: false, colorIndex: 0),
        TeamMember(id: "member-dahye", name: "임다혜", role: "Data Analyst", category: .research, isRecent: true, colorIndex: 2),
        TeamMember(id: "member-yuna", name: "한유나", role: "Brand Designer", category: .brand, isRecent: false, colorIndex: 1),
        TeamMember(id: "member-taeho", name: "강태호", role: "Marketing Designer", category: .brand, isRecent: false, colorIndex: 3),
        TeamMember(id: "member-joonho", name: "문준호", role: "PO", category: .product, isRecent: false, colorIndex: 0),
        TeamMember(id: "member-nari", name: "신나리", role: "Content Strategist", category: .product, isRecent: false, colorIndex: 1)
    ]
}

enum TeamCategory: String, CaseIterable, Identifiable {
    case product
    case design
    case engineering
    case research
    case brand

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .product:
            return "제품/기획"
        case .design:
            return "디자인팀"
        case .engineering:
            return "개발팀"
        case .research:
            return "리서치"
        case .brand:
            return "브랜드"
        }
    }
}
