//
//  ContentView.swift
//  Time Bracket
//
//  Created by 이희수 on 6/30/26.
//

import Combine
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedDate: Date?
    @State private var displayedMonth = Self.referenceMonth
    @State private var selectedTab: TopTab = .home
    @State private var calendarHeight = Self.expandedCalendarHeight
    @State private var meetings: [HomeMeeting] = []
    @State private var selectedMeeting: HomeMeeting?
    @State private var isCreateMeetingPresented = false

    private static let referenceDate = makeDate(year: 2026, month: 7, day: 15)
    private static let referenceMonth = makeDate(year: 2026, month: 7, day: 1)
    private static let expandedCalendarHeight: CGFloat = 306
    private static let collapsedCalendarHeight: CGFloat = 86
    private static let events: [ScheduleEvent] = []

    private let calendar = Self.appCalendar

    var body: some View {
        TabView(selection: $selectedTab) {
            VStack(spacing: 0) {
                CalendarHeader(title: "홈")
                HomeView(
                    meetings: meetings,
                    selectedMeeting: selectedMeeting,
                    onCreateMeeting: presentCreateMeeting,
                    onSelectMeeting: openMeeting
                )
            }
            .sheet(isPresented: $isCreateMeetingPresented) {
                createMeetingSheet
            }
            .tag(TopTab.home)
            .tabItem {
                Label("홈", systemImage: "house")
            }

            MeetingWorkspaceScreen(
                selectedDate: $selectedDate,
                displayedMonth: $displayedMonth,
                calendarHeight: $calendarHeight,
                expandedCalendarHeight: Self.expandedCalendarHeight,
                collapsedCalendarHeight: Self.collapsedCalendarHeight,
                events: Self.events,
                meeting: selectedMeeting,
                calendar: calendar,
                onShareWithMembers: shareHostAvailability
            )
            .tag(TopTab.calendar)
            .tabItem {
                Label("캘린더", systemImage: "calendar")
            }
        }
        .tint(.primary)
        .toolbarBackground(.hidden, for: .tabBar)
        .background(Color(uiColor: .systemBackground))
        .preferredColorScheme(.light)
    }

    private var createMeetingSheet: some View {
        CreateMeetingSheet(
            defaultStartDate: Self.referenceDate,
            onCancel: {
                isCreateMeetingPresented = false
            },
            onCreate: createMeetings
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private static var appCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return appCalendar.date(from: components) ?? Date()
    }

    private func presentCreateMeeting() {
        isCreateMeetingPresented = true
    }

    private func openMeeting(_ meeting: HomeMeeting) {
        selectedMeeting = meeting

        if let monthStart = calendar.dateInterval(of: .month, for: meeting.focusDate)?.start {
            displayedMonth = monthStart
            selectedDate = meeting.focusDate
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            selectedTab = .calendar
        }
    }

    private func createMeetings(from drafts: [MeetingDraft]) {
        let createdMeetings = drafts.map { makeHomeMeeting(from: $0) }

        meetings.insert(contentsOf: createdMeetings, at: 0)
        isCreateMeetingPresented = false

        if let firstMeeting = createdMeetings.first {
            openMeeting(firstMeeting)
        }
    }

    private func shareHostAvailability(for meetingID: String) {
        guard let meetingIndex = meetings.firstIndex(where: { $0.id == meetingID }) else {
            return
        }

        let updatedMeeting = meetings[meetingIndex].sharedWithMembers()
        meetings[meetingIndex] = updatedMeeting
        selectedMeeting = updatedMeeting
    }

    private func makeHomeMeeting(from draft: MeetingDraft) -> HomeMeeting {
        let candidateDates = candidateDates(from: draft.startDate, to: draft.endDate)
        let focusDate = candidateDates.first ?? draft.startDate
        return HomeMeeting(
            id: UUID().uuidString,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            sectionName: draft.sectionName,
            subtitle: meetingSubtitle(from: draft),
            dateRange: dateRangeText(for: candidateDates),
            timeRange: draft.availabilityWindowText,
            memberCount: draft.members.count + 1,
            respondedCount: 0,
            status: .waiting,
            stage: .hostAvailability,
            memberInitials: ["나"] + draft.members.map(\.name),
            focusDate: focusDate,
            candidateStartDate: draft.startDate,
            candidateEndDate: draft.endDate,
            confirmedDay: "\(calendar.component(.day, from: focusDate))",
            confirmedWeekday: weekdayText(for: focusDate)
        )
    }

    private func meetingSubtitle(from draft: MeetingDraft) -> String {
        let detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeText = location.isEmpty ? draft.meetingMode.title : "\(draft.meetingMode.title) · \(location)"
        let sectionText = draft.sectionName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !detail.isEmpty else {
            return [sectionText, placeText].filter { !$0.isEmpty }.joined(separator: " · ")
        }

        return [sectionText, detail, placeText].filter { !$0.isEmpty }.joined(separator: " · ")
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

    private func dateRangeText(for dates: [Date]) -> String {
        guard let firstDate = dates.first else {
            return "일정 미정"
        }

        guard let lastDate = dates.last, !calendar.isDate(firstDate, inSameDayAs: lastDate) else {
            return shortDateText(for: firstDate)
        }

        return "\(shortDateText(for: firstDate)) - \(shortDateText(for: lastDate))"
    }

    private func shortDateText(for date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private func weekdayText(for date: Date) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayIndex = max(calendar.component(.weekday, from: date) - 1, 0)
        return symbols[min(weekdayIndex, symbols.count - 1)]
    }
}

private enum TopTab {
    case home
    case calendar
}

private struct MeetingWorkspaceScreen: View {
    @Binding var selectedDate: Date?
    @Binding var displayedMonth: Date
    @Binding var calendarHeight: CGFloat

    let expandedCalendarHeight: CGFloat
    let collapsedCalendarHeight: CGFloat
    let events: [ScheduleEvent]
    let meeting: HomeMeeting?
    let calendar: Calendar
    let onShareWithMembers: (String) -> Void

    var body: some View {
        if let meeting {
            switch meeting.stage {
            case .hostAvailability, .collectingResponses:
                CalendarScreen(
                    selectedDate: $selectedDate,
                    displayedMonth: $displayedMonth,
                    calendarHeight: $calendarHeight,
                    expandedCalendarHeight: expandedCalendarHeight,
                    collapsedCalendarHeight: collapsedCalendarHeight,
                    events: events,
                    meeting: meeting,
                    calendar: calendar,
                    onShareWithMembers: onShareWithMembers
                )
            case .bracketReview:
                BracketReviewScreen(meeting: meeting)
            case .confirmed:
                ConfirmedMeetingScreen(meeting: meeting)
            }
        } else {
            EmptyCalendarWorkspaceScreen()
        }
    }
}

private struct EmptyCalendarWorkspaceScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "캘린더")

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("아직 생성된 회의가 없습니다")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("홈에서 새 회의 조율을 만들면 이곳에서 내 가능 시간을 입력할 수 있습니다.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private enum LayoutMetrics {
    static let horizontalPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 20
    static let calendarBottomPadding: CGFloat = 10
    static let calendarDayCellSize: CGFloat = 42
    static let timeAxisWidth: CGFloat = 24
    static let scheduleColumnSpacing: CGFloat = 5
    static let scheduleTrailingPadding: CGFloat = 12

    static var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 7)
    }
}

private struct CalendarScreen: View {
    @Binding var selectedDate: Date?
    @Binding var displayedMonth: Date
    @Binding var calendarHeight: CGFloat

    let expandedCalendarHeight: CGFloat
    let collapsedCalendarHeight: CGFloat
    let events: [ScheduleEvent]
    let meeting: HomeMeeting
    let calendar: Calendar
    let onShareWithMembers: (String) -> Void

    @State private var availabilityMode: AvailabilityMode = .available
    @State private var availabilityEntries: [AvailabilitySlot: AvailabilityEntry] = [:]
    @State private var reasonDraft: AvailabilityReasonDraft?
    @State private var isHostAvailabilityComplete = false
    @State private var isShareConfirmationPresented = false
    @State private var schedulePageIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                CalendarMonthHeader(
                    title: navigationTitle,
                    selectedDate: monthPickerDate,
                    isTodaySelected: isTodaySelected,
                    onTodayTap: moveToToday
                )

                CompactMeetingContextBar(
                    meeting: meeting,
                    statusText: isSharedCalendar ? "팀원 응답 보기" : "내 시간 입력"
                )

                GeometryReader { proxy in
                    let calendarAnimation = Animation.interactiveSpring(
                        response: 0.42,
                        dampingFraction: 0.9,
                        blendDuration: 0.12
                    )
                    let handleBandHeight: CGFloat = 20
                    let toolbarReservedInset: CGFloat = 76
                    let clampedCalendarHeight = min(
                        max(calendarHeight, collapsedCalendarHeight),
                        expandedCalendarHeight
                    )
                    let expansionProgress = (clampedCalendarHeight - collapsedCalendarHeight) / (expandedCalendarHeight - collapsedCalendarHeight)
                    let scheduleRowHeight: CGFloat = 44
                    let scheduleHeight = max(proxy.size.height - clampedCalendarHeight - handleBandHeight, 0)

                    VStack(spacing: 0) {
                        ZStack {
                            Color.primary

                            ExpandableCalendarView(
                                month: displayedMonth,
                                selectedDate: $selectedDate,
                                rangeStartDate: meeting.candidateStartDate,
                                rangeEndDate: meeting.candidateEndDate,
                                expansionProgress: expansionProgress,
                                calendar: calendar
                            )
                            .frame(height: clampedCalendarHeight, alignment: .top)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(
                                UnevenRoundedRectangle(
                                    cornerRadii: .init(
                                        bottomLeading: LayoutMetrics.panelCornerRadius,
                                        bottomTrailing: LayoutMetrics.panelCornerRadius
                                    ),
                                    style: .continuous
                                )
                            )
                        }
                        .frame(height: clampedCalendarHeight)
                        .simultaneousGesture(calendarMonthSwipeGesture)

                        CalendarDragHandle(
                            calendarHeight: $calendarHeight,
                            expandedCalendarHeight: expandedCalendarHeight,
                            collapsedCalendarHeight: collapsedCalendarHeight,
                            settleAnimation: calendarAnimation
                        )
                        .frame(height: handleBandHeight)

                        ZStack {
                            Color.primary

                            ScheduleGridView(
                                selectedDate: selectedDate,
                                visibleDates: visibleScheduleDates,
                                pageIndex: schedulePageIndex,
                                pageCount: scheduleDatePages.count,
                                events: events,
                                availabilityEntries: availabilityEntries,
                                teamResponseSummaries: isSharedCalendar ? teamResponseSummaries : [:],
                                isResponseMode: isSharedCalendar,
                                selectedAvailabilityMode: availabilityMode,
                                rowHeight: scheduleRowHeight,
                                bottomContentInset: toolbarReservedInset,
                                calendar: calendar,
                                onTapSlot: updateAvailabilitySlot,
                                onCommitSlots: commitAvailabilitySlots,
                                onEditAvailabilityBlock: editAvailabilityBlock,
                                onMovePage: moveSchedulePage
                            )
                            .frame(height: scheduleHeight)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    cornerRadii: .init(
                                        topLeading: LayoutMetrics.panelCornerRadius,
                                        topTrailing: LayoutMetrics.panelCornerRadius
                                    ),
                                    style: .continuous
                                )
                            )
                        }
                        .frame(height: scheduleHeight)
                    }
                }
            }

            Group {
                if isSharedCalendar {
                    SharedCalendarToolbar(
                        respondedCount: simulatedRespondedCount,
                        memberCount: meeting.memberCount,
                        onCompare: {
                            print("Open candidate comparison")
                        }
                    )
                } else {
                    AvailabilityInputToolbar(
                        selection: $availabilityMode,
                        canComplete: isAvailabilityReadyToComplete,
                        isComplete: isHostAvailabilityComplete,
                        onComplete: {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                isHostAvailabilityComplete = true
                            }
                        },
                        onShare: {
                            isShareConfirmationPresented = true
                        }
                    )
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(item: $reasonDraft) { draft in
            AvailabilityReasonSheet(
                draft: draft,
                calendar: calendar,
                onCancel: {
                    reasonDraft = nil
                },
                onSave: { reason in
                    applyReason(reason, to: draft.slots, mode: draft.mode)
                    reasonDraft = nil
                }
            )
            .presentationDetents([.height(410), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShareConfirmationPresented) {
            ShareCalendarSheet(
                meeting: meeting,
                availabilityCount: availabilityEntries.count,
                onCancel: {
                    isShareConfirmationPresented = false
                },
                onShare: {
                    isShareConfirmationPresented = false
                    onShareWithMembers(meeting.id)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var navigationTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 2026)년 \(components.month ?? 7)월"
    }

    private var isSharedCalendar: Bool {
        meeting.stage == .collectingResponses
    }

    private var simulatedRespondedCount: Int {
        min(max(meeting.respondedCount, max(meeting.memberCount - 2, 1)), meeting.memberCount)
    }

    private var monthPickerDate: Binding<Date> {
        Binding(
            get: {
                displayedMonth
            },
            set: { newDate in
                jumpToDisplayedMonth(containing: newDate)
            }
        )
    }

    private var isTodaySelected: Bool {
        guard let selectedDate else {
            return false
        }

        return calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    private var candidateDates: [Date] {
        var dates: [Date] = []
        let startDate = calendar.startOfDay(for: min(meeting.candidateStartDate, meeting.candidateEndDate))
        let endDate = calendar.startOfDay(for: max(meeting.candidateStartDate, meeting.candidateEndDate))
        var offset = 0

        while true {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate), date <= endDate else {
                break
            }

            dates.append(date)
            offset += 1
        }

        return dates.isEmpty ? [calendar.startOfDay(for: meeting.focusDate)] : dates
    }

    private var scheduleDatePages: [[Date]] {
        stride(from: 0, to: candidateDates.count, by: 5).map { startIndex in
            Array(candidateDates[startIndex..<min(startIndex + 5, candidateDates.count)])
        }
    }

    private var visibleScheduleDates: [Date] {
        let pages = scheduleDatePages
        guard !pages.isEmpty else {
            return []
        }

        return pages[min(schedulePageIndex, pages.count - 1)]
    }

    private var isAvailabilityReadyToComplete: Bool {
        let requiredSlots = requiredAvailabilitySlots
        guard !requiredSlots.isEmpty else {
            return false
        }

        return requiredSlots.allSatisfy { slot in
            guard let entry = availabilityEntries[slot] else {
                return false
            }

            if entry.mode.requiresReason {
                return !(entry.reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            return true
        }
    }

    private var requiredAvailabilitySlots: [AvailabilitySlot] {
        candidateDates.flatMap { date in
            (9..<18).map { hour in
                AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
            }
        }
    }

    private var teamResponseSummaries: [AvailabilitySlot: TeamResponseSummary] {
        let fallbackNames = ["나", "김민준", "이서연", "오유진", "송승아", "박도윤"]
        let memberNames = (meeting.memberInitials.isEmpty ? fallbackNames : meeting.memberInitials)
        let normalizedNames = (0..<max(meeting.memberCount, memberNames.count)).map { index in
            index < memberNames.count ? memberNames[index] : "팀원 \(index)"
        }
        let burdenReasons = ["앞 일정과 붙어 있음", "이동 시간이 필요함", "준비 시간이 부족함"]
        let unavailableReasons = ["이미 확정된 회의", "외부 미팅", "개인 일정"]
        var summaries: [AvailabilitySlot: TeamResponseSummary] = [:]

        for (dayIndex, date) in candidateDates.enumerated() {
            for hour in 9..<18 {
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                var available: [String] = []
                var burden: [TeamResponseReason] = []
                var unavailable: [TeamResponseReason] = []

                for (memberIndex, name) in normalizedNames.enumerated() {
                    if memberIndex == 0, let hostEntry = availabilityEntries[slot] {
                        switch hostEntry.mode {
                        case .available:
                            available.append(name)
                        case .burden:
                            burden.append(TeamResponseReason(name: name, reason: hostEntry.reason ?? "조정 가능"))
                        case .unavailable:
                            unavailable.append(TeamResponseReason(name: name, reason: hostEntry.reason ?? "참석 어려움"))
                        }
                        continue
                    }

                    let seed = dayIndex * 11 + hour + memberIndex * 3
                    if seed % 9 == 0 {
                        unavailable.append(
                            TeamResponseReason(
                                name: name,
                                reason: unavailableReasons[seed % unavailableReasons.count]
                            )
                        )
                    } else if seed % 5 == 0 {
                        burden.append(
                            TeamResponseReason(
                                name: name,
                                reason: burdenReasons[seed % burdenReasons.count]
                            )
                        )
                    } else {
                        available.append(name)
                    }
                }

                summaries[slot] = TeamResponseSummary(
                    availableNames: available,
                    burdenMembers: burden,
                    unavailableMembers: unavailable
                )
            }
        }

        return summaries
    }

    private var availabilityStateAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.92, blendDuration: 0.04)
    }

    private var calendarMonthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > abs(verticalDistance), abs(horizontalDistance) > 46 else {
                    return
                }

                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
                    moveDisplayedMonth(by: horizontalDistance < 0 ? 1 : -1)
                }
            }
    }

    private func moveDisplayedMonth(by value: Int) {
        guard
            let candidateMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth),
            let nextMonth = calendar.dateInterval(of: .month, for: candidateMonth)?.start
        else {
            return
        }

        displayedMonth = nextMonth
        selectedDate = nil
    }

    private func jumpToDisplayedMonth(containing date: Date) {
        guard
            let monthStart = calendar.dateInterval(of: .month, for: date)?.start
        else {
            return
        }

        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
            displayedMonth = monthStart
            selectedDate = nil
        }
    }

    private func moveToToday() {
        let today = calendar.startOfDay(for: Date())

        guard
            let monthStart = calendar.dateInterval(of: .month, for: today)?.start
        else {
            return
        }

        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
            displayedMonth = monthStart
            selectedDate = today
        }
    }

    private func updateAvailabilitySlot(_ slot: AvailabilitySlot) {
        if availabilityMode.requiresReason {
            setAvailabilityMode(availabilityMode, for: [slot], keepsExistingReason: true)
            presentReasonSheet(for: [slot], mode: availabilityMode)
            return
        }

        withAnimation(availabilityStateAnimation) {
            if availabilityEntries[slot]?.mode == availabilityMode {
                availabilityEntries.removeValue(forKey: slot)
            } else {
                availabilityEntries[slot] = AvailabilityEntry(mode: availabilityMode, reason: nil)
            }

            isHostAvailabilityComplete = false
        }
    }

    private func commitAvailabilitySlots(_ slots: Set<AvailabilitySlot>) {
        guard !slots.isEmpty else {
            return
        }

        if availabilityMode == .available, areAllSlots(slots, in: .available) {
            clearAvailabilitySlots(slots)
            return
        }

        setAvailabilityMode(availabilityMode, for: slots, keepsExistingReason: true)

        if availabilityMode.requiresReason {
            presentReasonSheet(for: slots, mode: availabilityMode)
        }
    }

    private func areAllSlots(_ slots: Set<AvailabilitySlot>, in mode: AvailabilityMode) -> Bool {
        slots.allSatisfy { availabilityEntries[$0]?.mode == mode }
    }

    private func clearAvailabilitySlots(_ slots: Set<AvailabilitySlot>) {
        guard !slots.isEmpty else {
            return
        }

        withAnimation(availabilityStateAnimation) {
            for slot in slots {
                availabilityEntries.removeValue(forKey: slot)
            }

            isHostAvailabilityComplete = false
        }
    }

    private func setAvailabilityMode(_ mode: AvailabilityMode, for slots: Set<AvailabilitySlot>, keepsExistingReason: Bool) {
        guard !slots.isEmpty else {
            return
        }

        withAnimation(availabilityStateAnimation) {
            for slot in slots {
                let existingEntry = availabilityEntries[slot]
                let reason = keepsExistingReason && existingEntry?.mode == mode ? existingEntry?.reason : nil
                availabilityEntries[slot] = AvailabilityEntry(mode: mode, reason: mode.requiresReason ? reason : nil)
            }

            isHostAvailabilityComplete = false
        }
    }

    private func presentReasonSheet(for slots: Set<AvailabilitySlot>, mode: AvailabilityMode) {
        guard mode.requiresReason, !slots.isEmpty else {
            return
        }

        let existingReasons = Set(
            slots.compactMap { slot in
                availabilityEntries[slot]?.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        )

        reasonDraft = AvailabilityReasonDraft(
            mode: mode,
            slots: slots,
            initialReason: existingReasons.count == 1 ? existingReasons.first ?? "" : ""
        )
    }

    private func applyReason(_ reason: String, to slots: Set<AvailabilitySlot>, mode: AvailabilityMode) {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            return
        }

        withAnimation(availabilityStateAnimation) {
            for slot in slots {
                availabilityEntries[slot] = AvailabilityEntry(mode: mode, reason: trimmedReason)
            }

            isHostAvailabilityComplete = false
        }
    }

    private func editAvailabilityBlock(_ detail: AvailabilityBlockDetail) {
        guard detail.mode.requiresReason else {
            return
        }

        let slots = Set((detail.startHour..<detail.endHour).map {
            AvailabilitySlot(date: detail.date, hour: $0)
        })

        presentReasonSheet(for: slots, mode: detail.mode)
    }

    private func moveSchedulePage(by offset: Int) {
        let pages = scheduleDatePages
        let maxIndex = max(pages.count - 1, 0)
        let nextIndex = min(max(schedulePageIndex + offset, 0), maxIndex)

        guard nextIndex != schedulePageIndex else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            schedulePageIndex = nextIndex
            selectedDate = pages[nextIndex].first
        }
    }
}

private struct CompactMeetingContextBar: View {
    let meeting: HomeMeeting
    let statusText: String

    var body: some View {
        Button {
            print("Open meeting detail")
        } label: {
            HStack(spacing: 8) {
                Text(meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 8)

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct AvailabilityInputToolbar: View {
    @Binding var selection: AvailabilityMode
    let canComplete: Bool
    let isComplete: Bool
    let onComplete: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            modeSegment

            Button(action: isComplete ? onShare : onComplete) {
                Label(isComplete ? "공유" : "완료", systemImage: isComplete ? "paperplane.fill" : "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(canComplete ? .white : Color(uiColor: .tertiaryLabel))
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(canComplete ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray5), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canComplete)
            .opacity(canComplete ? 1 : 0.78)
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 7)
    }

    private var modeSegment: some View {
        HStack(spacing: 4) {
            ForEach(AvailabilityMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        selection = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == mode ? .white : mode.tint)
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        .background(selection == mode ? mode.tint : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemFill).opacity(0.72), in: Capsule())
    }
}

private struct SharedCalendarToolbar: View {
    let respondedCount: Int
    let memberCount: Int
    let onCompare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                toolbarChip("내 입력", isSelected: false)
                toolbarChip("팀원 응답", isSelected: true)
            }
            .padding(3)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemFill).opacity(0.72), in: Capsule())

            Button(action: onCompare) {
                Label("후보 비교", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color(uiColor: .systemBlue), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 7)
        .overlay(alignment: .top) {
            Text("\(respondedCount)/\(memberCount) 응답")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(.regularMaterial, in: Capsule())
                .offset(y: -28)
        }
    }

    private func toolbarChip(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(uiColor: .label) : Color.clear, in: Capsule())
    }
}

private struct ShareCalendarSheet: View {
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

                        AvatarStack(names: inviteeInitials.prefix(4).map { $0 })
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

private enum ShareAction: String, Identifiable {
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

private struct ShareActionButton: View {
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

private struct ShareActionIcon: View {
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

private struct ShareSummaryRow: View {
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

private struct AvailabilityReasonSheet: View {
    let draft: AvailabilityReasonDraft
    let calendar: Calendar
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var reason: String
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
        _reason = State(initialValue: draft.initialReason)
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
                        onSave(reason)
                    }
                    .fontWeight(.semibold)
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(suggestionRows.enumerated()), id: \.offset) { _, row in
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

    private func reasonChip(_ suggestion: String) -> some View {
        let isSelected = reason == suggestion

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                reason = suggestion
            }
        } label: {
            Text(suggestion)
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

    private var suggestionRows: [[String]] {
        stride(from: 0, to: draft.mode.reasonSuggestions.count, by: 2).map { index in
            Array(draft.mode.reasonSuggestions[index..<min(index + 2, draft.mode.reasonSuggestions.count)])
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
}

private struct AvailabilityEntry {
    let mode: AvailabilityMode
    let reason: String?
}

private struct AvailabilityReasonDraft: Identifiable {
    let id = UUID()
    let mode: AvailabilityMode
    let slots: Set<AvailabilitySlot>
    let initialReason: String
}

private enum AvailabilityMode: String, CaseIterable, Identifiable {
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
            return ["앞 일정과 붙어 있음", "이동 시간이 필요함", "집중 업무 시간", "준비 시간이 부족함"]
        case .unavailable:
            return ["이미 확정된 회의", "외부 미팅", "휴가/반차", "개인 일정"]
        }
    }
}

private struct CalendarHeader: View {
    let title: String

    var body: some View {
        HStack {
            headerTitle

            Spacer()
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private var headerTitle: some View {
        Text(title)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

private struct CalendarMonthHeader: View {
    let title: String
    @Binding var selectedDate: Date
    let isTodaySelected: Bool
    let onTodayTap: () -> Void

    @State private var isPickerPresented = false

    var body: some View {
        HStack {
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .offset(y: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPickerPresented, attachmentAnchor: .point(.bottomLeading)) {
                YearMonthWheelPicker(
                    selectedDate: $selectedDate,
                    isPresented: $isPickerPresented
                )
                .frame(width: 320, height: 286)
                .presentationBackground(.regularMaterial)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("월 선택")

            Spacer()

            Button(action: onTodayTap) {
                Text("오늘")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isTodaySelected ? .secondary : .primary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(isTodaySelected ? 0.28 : 0.55), lineWidth: 0.8)
                    }
                    .shadow(color: Color.black.opacity(isTodaySelected ? 0.02 : 0.05), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(isTodaySelected)
            .opacity(isTodaySelected ? 0.62 : 1)
            .accessibilityLabel("오늘로 이동")
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct MeetingContextBar: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(meeting.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(meeting.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                StatusPill(status: meeting.status)
            }

            HStack(spacing: 10) {
                MeetingMetaBadge(text: meeting.dateRange, systemImage: "calendar")
                MeetingMetaBadge(text: meeting.timeRange, systemImage: "clock")

                Spacer(minLength: 8)

                AvatarStack(names: meeting.memberInitials.prefix(4).map { $0 })

                Text("\(meeting.respondedCount)/\(meeting.memberCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.bottom, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct MeetingMetaBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
}

private struct ResponseCollectionScreen: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "응답 현황")
            MeetingContextBar(meeting: meeting)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: HomeGridMetrics.gap) {
                    WorkspaceStatusCard(
                        title: "\(meeting.respondedCount)명 입력 완료",
                        detail: "\(meeting.remainingCount)명의 응답을 기다리는 중",
                        symbolName: "person.2.badge.clock",
                        tint: Color(uiColor: .systemBlue)
                    )

                    ParticipantStatusBlock(meeting: meeting)

                    WorkspaceActionCard(
                        title: "공유 링크",
                        detail: "참석자에게 다시 전달",
                        buttonTitle: "공유"
                    )
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 88)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct BracketReviewScreen: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "브래킷 검토")
            MeetingContextBar(meeting: meeting)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: HomeGridMetrics.gap) {
                    WorkspaceStatusCard(
                        title: "후보 시간 비교 준비",
                        detail: "시스템 추천과 주최자 판단을 함께 반영",
                        symbolName: "trophy",
                        tint: Color(uiColor: .systemPurple)
                    )

                    CandidateTimeBlock()

                    WorkspaceActionCard(
                        title: "최종 시간 선택",
                        detail: "추천 후보 중 하나를 확정",
                        buttonTitle: "확정하기"
                    )
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 88)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct ConfirmedMeetingScreen: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "확정된 회의")
            MeetingContextBar(meeting: meeting)

            VStack(spacing: HomeGridMetrics.gap) {
                WorkspaceStatusCard(
                    title: "\(meeting.confirmedDay)일 \(meeting.timeRange)",
                    detail: "\(meeting.title) 시간이 확정됨",
                    symbolName: "checkmark.circle.fill",
                    tint: Color(uiColor: .systemGreen)
                )

                WorkspaceActionCard(
                    title: "캘린더에 추가",
                    detail: "확정된 일정을 내 캘린더로 반영",
                    buttonTitle: "추가"
                )

                Spacer()
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct WorkspaceHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct WorkspaceStatusCard: View {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct ParticipantStatusBlock: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("참석자")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            ForEach(Array(meeting.memberInitials.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 12) {
                    ProfileAvatar(
                        name: name,
                        fallback: ProfileAsset.fallbackText(for: name),
                        size: 32,
                        tint: AvatarStack.colors[index % AvatarStack.colors.count]
                    )

                    Text(index < meeting.respondedCount ? "입력 완료" : "응답 대기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: index < meeting.respondedCount ? "checkmark.circle.fill" : "clock")
                        .foregroundStyle(index < meeting.respondedCount ? Color(uiColor: .systemGreen) : Color(uiColor: .systemGray2))
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct CandidateTimeBlock: View {
    private let candidates = [
        ("7월 16일", "14:00 - 15:00", "92점"),
        ("7월 17일", "10:00 - 11:00", "86점"),
        ("7월 16일", "15:00 - 16:00", "78점")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("추천 후보")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .systemBackground), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.0)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(candidate.1)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(candidate.2)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct WorkspaceActionCard: View {
    let title: String
    let detail: String
    let buttonTitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                print(buttonTitle)
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct YearMonthWheelPicker: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    @State private var year: Int
    @State private var month: Int

    private let years = Array(2020...2035)
    private let months = Array(1...12)
    private let calendar: Calendar

    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        _selectedDate = selectedDate
        _isPresented = isPresented

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        self.calendar = calendar

        let components = calendar.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        _year = State(initialValue: components.year ?? 2026)
        _month = State(initialValue: components.month ?? 7)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") {
                    isPresented = false
                }
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)

                Spacer()

                Text("년월 선택")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button("완료") {
                    applySelection()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .frame(height: 50)

            Divider()

            HStack(spacing: 0) {
                Picker("년도", selection: $year) {
                    ForEach(years, id: \.self) { year in
                        Text(Self.yearLabel(year))
                            .font(.system(size: 22, weight: .regular))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("월", selection: $month) {
                    ForEach(months, id: \.self) { month in
                        Text(Self.monthLabel(month))
                            .font(.system(size: 22, weight: .regular))
                            .tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 220)
            .padding(.horizontal, 8)
        }
        .background(.regularMaterial)
        .preferredColorScheme(.light)
    }

    private static func yearLabel(_ year: Int) -> String {
        String(format: "%d년", year)
    }

    private static func monthLabel(_ month: Int) -> String {
        String(format: "%d월", month)
    }

    private func applySelection() {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        if let date = calendar.date(from: components) {
            selectedDate = date
        }

        isPresented = false
    }
}

private struct CreateMeetingSheet: View {
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

                scheduleSettingRow(title: "소요 시간", systemImage: "hourglass") {
                    Text(meetingDurationText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
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
            meetingDurationText
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
            meetingMode: meetingInfo.meetingMode,
            location: meetingInfo.location,
            startDate: startDate,
            endDate: endDate,
            availabilityWindowText: availabilityWindowText,
            durationText: meetingDurationText,
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

private enum CreateMeetingLayout {
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

private enum CreateMeetingStep: Int, CaseIterable, Identifiable {
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

private struct CreateMeetingStepBar: View {
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

private struct CreateMeetingStepChip: View {
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
                    .font(.system(size: 13, weight: .semibold))
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

private struct CurrentStepHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .frame(height: 32, alignment: .center)
    }
}

private struct DateRangeCalendarPicker: View {
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

private struct DateRangeDayCell: View {
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

private struct ReviewCandidateCalendarWidget: View {
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

private struct MiniRangeDayCell: View {
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

private struct ReviewMeetingInfoSquareCard: View {
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

private struct ReviewMeetingInfoMiniLine: View {
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

private struct ReviewScheduleOverviewCard: View {
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

private struct ReviewCompactMetricCard: View {
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

private struct ReviewMeetingOverviewCard<Content: View>: View {
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

private struct ReviewMeetingTile: View {
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

private struct ReviewInviteeListCard: View {
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

                AvatarStack(names: members.prefix(5).map(\.name))
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

private struct ReviewInviteeDetailCard: View {
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

private struct ReviewInviteeDetailRow: View {
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

private struct ReviewCandidateDateRow: Hashable {
    let dateText: String
    let weekday: String
    let isWeekend: Bool
}

private struct ReviewPressableCard<Content: View>: View {
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

private struct ReviewDetailSummaryCard<Content: View>: View {
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

private struct ReviewDetailSectionCard<Content: View>: View {
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

private struct ReviewMeetingInfoDetailCard: View {
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

private struct ReviewMeetingInfoMetaRow: View {
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

private struct ReviewMeetingInfoDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 28)
    }
}

private struct ReviewCardHeader: View {
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

private struct ReviewChipRow<Content: View>: View {
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

private struct ReviewMetaPill: View {
    let text: String
    let systemImage: String
    var tint: Color?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint ?? Color(uiColor: .secondaryLabel))
                .frame(width: 13, height: 13)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint == nil ? Color(uiColor: .secondaryLabel) : Color(uiColor: .label))
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
}

private struct ReviewColorPill: View {
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

private struct ReviewDisclosureButton: View {
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

private struct ReviewDetailLine: View {
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

private struct ReviewCompactParticipantRow: View {
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

private struct ReviewSectionCard<Content: View>: View {
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

private struct ReviewInfoRow: View {
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

private struct ReviewMeetingSummary: View {
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

private struct ReviewCalendarTextRow: View {
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

private struct ReviewTextRow: View {
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

private struct ReviewParticipantRow: View {
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

private struct ReviewDivider: View {
    var body: some View {
        Divider()
    }
}

private struct ReviewSummaryBlock: View {
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

private struct FlowChipRow: View {
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

private struct ParticipantLimitSummaryRow: View {
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

private struct CreateMeetingAddActionButton: View {
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

private struct HostParticipantRow: View {
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

private struct SelectedParticipantRow: View {
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

private struct ParticipantRowBackground: View {
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

private struct ParticipantPickerSheet: View {
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

private struct ParticipantPickerSectionHeader: View {
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

private enum MeetingInfoLayout {
    static let labelWidth: CGFloat = 70
    static let rowHeight: CGFloat = CreateMeetingLayout.rowHeight
    static let horizontalPadding: CGFloat = 0
    static let columnSpacing: CGFloat = 12
    static let dividerLeading: CGFloat = labelWidth + columnSpacing + horizontalPadding
}

private struct MeetingInfoDraft: Identifiable, Equatable {
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

private enum MeetingInfoField: Hashable {
    case title(String)
    case location(String)
    case detail(String)
}

private struct MeetingInfoCard: View {
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

private struct MeetingIconPickerButton: View {
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

private enum MeetingIconStyle {
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

private struct MeetingInfoTextFieldRow: View {
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

private struct MeetingModeRow: View {
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

private struct MeetingModeSegmentControl: View {
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

private struct MeetingInfoCalendarRow: View {
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
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
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

private enum CalendarSectionTint {
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

private struct MeetingInfoDetailRow: View {
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

private struct MeetingInfoLabel: View {
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

private struct MeetingInfoDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, MeetingInfoLayout.dividerLeading)
    }
}

private struct LabeledTextField: View {
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

private struct MeetingDraft {
    let title: String
    let detail: String
    let sectionName: String
    let meetingMode: MeetingMode
    let location: String
    let startDate: Date
    let endDate: Date
    let availabilityWindowText: String
    let durationText: String
    let members: [MeetingMemberDraft]
}

private enum MeetingMode: String, CaseIterable, Identifiable {
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

private struct MeetingMemberDraft: Identifiable {
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

private struct TeamMember: Identifiable, Equatable {
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

private enum TeamCategory: String, CaseIterable, Identifiable {
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

private struct HomeView: View {
    let meetings: [HomeMeeting]
    let selectedMeeting: HomeMeeting?
    let onCreateMeeting: () -> Void
    let onSelectMeeting: (HomeMeeting) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: HomeGridMetrics.gap) {
                NewMeetingCard(onCreate: onCreateMeeting)

                HomeSummaryBlock(meetings: meetings)

                MeetingGroupBlock(
                    meetings: meetings.filter { $0.status != .confirmed },
                    selectedMeeting: selectedMeeting,
                    onSelectMeeting: onSelectMeeting
                )

                HomeTimelineCard(meetings: meetings)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, HomeGridMetrics.topPadding)
            .padding(.bottom, 88)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private enum HomeGridMetrics {
    static let gap: CGFloat = 10
    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let singleHeight: CGFloat = 156
    static let wideHeight: CGFloat = 156
    static let featureHeight: CGFloat = 184
    static let topPadding: CGFloat = 8

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

private struct HomeSummaryBlock: View {
    let meetings: [HomeMeeting]

    var body: some View {
        HStack(spacing: HomeGridMetrics.gap) {
            HomeMetricCard(
                title: "조율 중",
                value: "\(meetings.filter { $0.status != .confirmed }.count)",
                detail: "내가 만든 회의",
                symbolName: "calendar.badge.clock",
                tint: Color(uiColor: .systemBlue)
            )

            HomeMetricCard(
                title: "입력 필요",
                value: "\(meetings.filter { $0.status == .waiting }.count)",
                detail: "초대받은 회의",
                symbolName: "pencil.and.list.clipboard",
                tint: Color(uiColor: .systemOrange)
            )
        }
    }
}

private struct MeetingGroupBlock: View {
    let meetings: [HomeMeeting]
    let selectedMeeting: HomeMeeting?
    let onSelectMeeting: (HomeMeeting) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("진행 중인 조율")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("응답 상태와 다음 액션")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(meetings.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .systemBackground), in: Circle())
            }
            .padding(.bottom, 12)

            if meetings.isEmpty {
                EmptyMeetingRowsView()
            } else {
                ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                    MeetingRowCard(
                        meeting: meeting,
                        isSelected: meeting.id == selectedMeeting?.id,
                        onSelect: {
                            onSelectMeeting(meeting)
                        }
                    )

                    if index < meetings.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct EmptyMeetingRowsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("진행 중인 조율이 없습니다")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text("새 회의 조율을 만들면 여기에 바로 추가됩니다.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 2)
    }
}

private struct MeetingRowCard: View {
    let meeting: HomeMeeting
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ResponseProgressView(progress: meeting.responseProgress)
                    .frame(width: 38, height: 38)
                    .scaleEffect(0.72)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(meeting.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        StatusPill(status: meeting.status)
                            .scaleEffect(0.9, anchor: .leading)
                    }

                    Text("\(meeting.dateRange) · \(meeting.timeRange)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    AvatarStack(names: meeting.memberInitials.prefix(3).map { $0 })

                    Text("\(meeting.respondedCount)/\(meeting.memberCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color(uiColor: .systemBackground).opacity(0.72) : Color.clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct NewMeetingCard: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("새 회의 조율")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("후보 일정, 시간, 멤버 초대")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .leading)
            .background(.regularMaterial, in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
            .overlay {
                HomeGridMetrics.cardShape
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.singleHeight, maxHeight: HomeGridMetrics.singleHeight, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct FeaturedMeetingCard: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(meeting.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(meeting.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusPill(status: meeting.status)
            }

            HStack(spacing: 8) {
                Label(meeting.dateRange, systemImage: "calendar")
                Label(meeting.timeRange, systemImage: "clock")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            HStack(spacing: 12) {
                ResponseProgressView(progress: meeting.responseProgress)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(meeting.respondedCount)명 응답")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("총 \(meeting.memberCount)명 중 \(meeting.remainingCount)명 남음")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                AvatarStack(names: meeting.memberInitials)
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.featureHeight, maxHeight: HomeGridMetrics.featureHeight, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct CompactMeetingCard: View {
    let meeting: HomeMeeting

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusPill(status: meeting.status)

            Spacer(minLength: 0)

            Text(meeting.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(meeting.dateRange)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                AvatarStack(names: meeting.memberInitials.prefix(3).map { $0 })

                Spacer()

                Text("\(meeting.respondedCount)/\(meeting.memberCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.singleHeight, maxHeight: HomeGridMetrics.singleHeight, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct HomeTimelineCard: View {
    let meetings: [HomeMeeting]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("최근 확정")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("이번 주")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(meetings.filter { $0.status == .confirmed }) { meeting in
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text(meeting.confirmedDay)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(meeting.confirmedWeekday)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 42, height: 48)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(meeting.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(meeting.timeRange)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.wideHeight, maxHeight: HomeGridMetrics.wideHeight, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct StatusPill: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

private struct ResponseProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .systemGray5), lineWidth: 7)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 54, height: 54)
    }
}

private enum ProfileAsset {
    static func imageName(for name: String) -> String? {
        imageNames[normalized(name)]
    }

    static func fallbackText(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "?"
        }

        if trimmed.count <= 2 {
            return trimmed
        }

        return String(trimmed.prefix(1))
    }

    private static func normalized(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    private static let imageNames: [String: String] = [
        "나": "ProfileHeesu",
        "강태호": "ProfileTaeho",
        "이희수": "ProfileHeesu",
        "김민준": "ProfileMinjun",
        "문준호": "ProfileJoonho",
        "박도윤": "ProfileDoyoon",
        "송승아": "ProfileSeungah",
        "신나리": "ProfileNari",
        "오유진": "ProfileYujin",
        "윤재현": "ProfileJaehyun",
        "이서연": "ProfileSeoyeon",
        "임다혜": "ProfileDahye",
        "장혜진": "ProfileHyejin",
        "정지우": "ProfileJiwoo",
        "최하린": "ProfileHarin",
        "한유나": "ProfileYuna"
    ]
}

private struct ProfileAvatar: View {
    let name: String
    var fallback: String?
    var size: CGFloat
    var tint: Color
    var borderColor: Color = Color(uiColor: .secondarySystemBackground)
    var borderWidth: CGFloat = 0

    var body: some View {
        Group {
            if let imageName = ProfileAsset.imageName(for: name) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(fallback ?? ProfileAsset.fallbackText(for: name))
                    .font(.system(size: max(size * 0.35, 10), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(tint, in: Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if borderWidth > 0 {
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
    }
}

private struct AvatarStack: View {
    let names: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                ProfileAvatar(
                    name: name,
                    fallback: ProfileAsset.fallbackText(for: name),
                    size: 28,
                    tint: Self.colors[index % Self.colors.count],
                    borderColor: Color(uiColor: .secondarySystemBackground),
                    borderWidth: 2
                )
            }
        }
        .frame(height: 28)
    }

    static let colors = [
        Color(uiColor: .systemIndigo),
        Color(uiColor: .systemTeal),
        Color(uiColor: .systemPink),
        Color(uiColor: .systemGreen)
    ]
}

private struct HomeMeeting: Identifiable {
    let id: String
    let title: String
    let sectionName: String
    let subtitle: String
    let dateRange: String
    let timeRange: String
    let memberCount: Int
    let respondedCount: Int
    let status: MeetingStatus
    let stage: MeetingStage
    let memberInitials: [String]
    let focusDate: Date
    let candidateStartDate: Date
    let candidateEndDate: Date
    let confirmedDay: String
    let confirmedWeekday: String

    var remainingCount: Int {
        max(memberCount - respondedCount, 0)
    }

    var responseProgress: Double {
        guard memberCount > 0 else {
            return 0
        }

        return Double(respondedCount) / Double(memberCount)
    }

    func sharedWithMembers() -> HomeMeeting {
        HomeMeeting(
            id: id,
            title: title,
            sectionName: sectionName,
            subtitle: subtitle,
            dateRange: dateRange,
            timeRange: timeRange,
            memberCount: memberCount,
            respondedCount: max(respondedCount, 1),
            status: .collecting,
            stage: .collectingResponses,
            memberInitials: memberInitials,
            focusDate: focusDate,
            candidateStartDate: candidateStartDate,
            candidateEndDate: candidateEndDate,
            confirmedDay: confirmedDay,
            confirmedWeekday: confirmedWeekday
        )
    }

    static let sampleData = [
        HomeMeeting(
            id: "design-team-weekly",
            title: "디자인팀 회의",
            sectionName: "디자인팀",
            subtitle: "제품 방향성, IA, 화면 우선순위",
            dateRange: "7월 15일 - 18일",
            timeRange: "10:00 - 17:00",
            memberCount: 5,
            respondedCount: 3,
            status: .collecting,
            stage: .hostAvailability,
            memberInitials: ["나", "김민준", "이서연", "오유진", "송승아"],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 15),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 15),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 18),
            confirmedDay: "15",
            confirmedWeekday: "수"
        ),
        HomeMeeting(
            id: "product-review",
            title: "제품 리뷰",
            sectionName: "제품팀",
            subtitle: "MVP 범위 점검",
            dateRange: "7월 16일 - 17일",
            timeRange: "14:00 - 16:00",
            memberCount: 4,
            respondedCount: 4,
            status: .ready,
            stage: .bracketReview,
            memberInitials: ["나", "문준호", "오유진", "정지우"],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 16),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 16),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 17),
            confirmedDay: "16",
            confirmedWeekday: "목"
        ),
        HomeMeeting(
            id: "research-sync",
            title: "리서치 싱크",
            sectionName: "리서치",
            subtitle: "인터뷰 결과 공유",
            dateRange: "7월 21일 - 22일",
            timeRange: "09:00 - 12:00",
            memberCount: 6,
            respondedCount: 2,
            status: .waiting,
            stage: .collectingResponses,
            memberInitials: ["나", "정지우", "임다혜", "장혜진", "윤재현", "최하린"],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 21),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 21),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 22),
            confirmedDay: "21",
            confirmedWeekday: "화"
        ),
        HomeMeeting(
            id: "brand-check",
            title: "브랜드 체크인",
            sectionName: "브랜드",
            subtitle: "가이드라인 확정",
            dateRange: "7월 14일",
            timeRange: "11:00 - 12:00",
            memberCount: 3,
            respondedCount: 3,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: ["나", "한유나", "강태호"],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 14),
            confirmedDay: "14",
            confirmedWeekday: "화"
        )
    ]

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ko_KR")

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return calendar.date(from: components) ?? Date()
    }
}

private enum MeetingStage: Equatable {
    case hostAvailability
    case collectingResponses
    case bracketReview
    case confirmed
}

private enum MeetingStatus: Equatable {
    case collecting
    case waiting
    case ready
    case confirmed

    var title: String {
        switch self {
        case .collecting:
            return "응답 수집"
        case .waiting:
            return "내 입력 필요"
        case .ready:
            return "확정 대기"
        case .confirmed:
            return "확정"
        }
    }

    var tint: Color {
        switch self {
        case .collecting:
            return Color(uiColor: .systemBlue)
        case .waiting:
            return Color(uiColor: .systemOrange)
        case .ready:
            return Color(uiColor: .systemPurple)
        case .confirmed:
            return Color(uiColor: .systemGreen)
        }
    }
}

private struct ExpandableCalendarView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let expansionProgress: CGFloat
    let calendar: Calendar

    var body: some View {
        ZStack(alignment: .top) {
            MonthCalendarView(
                month: month,
                selectedDate: $selectedDate,
                rangeStartDate: rangeStartDate,
                rangeEndDate: rangeEndDate,
                calendar: calendar
            )
            .opacity(expansionProgress)
            .scaleEffect(0.985 + 0.015 * expansionProgress, anchor: .top)
            .allowsHitTesting(expansionProgress > 0.5)

            WeekStripView(
                month: month,
                selectedDate: $selectedDate,
                rangeStartDate: rangeStartDate,
                rangeEndDate: rangeEndDate,
                calendar: calendar
            )
            .opacity(1 - expansionProgress)
            .scaleEffect(1 - 0.015 * expansionProgress, anchor: .top)
            .allowsHitTesting(expansionProgress <= 0.5)
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct MonthCalendarView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 14) {
            weekdayRow

            LazyVGrid(columns: LayoutMetrics.calendarColumns, spacing: 13) {
                ForEach(monthDays) { day in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDate = day.date
                        }
                    } label: {
                        CalendarDayCell(
                            date: day.date,
                            isSelected: isSelected(day.date),
                            isCurrentMonth: day.isCurrentMonth,
                            isRangeStart: isRangeStart(day.date),
                            isRangeEnd: isRangeEnd(day.date),
                            isInRange: isInRange(day.date),
                            isSingleDayRange: isSingleDayRange,
                            isWeekStart: isWeekStart(day.date),
                            isWeekEnd: isWeekEnd(day.date),
                            continuesFromPreviousWeek: continuesFromPreviousWeek(day.date),
                            continuesToNextWeek: continuesToNextWeek(day.date),
                            calendar: calendar
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, LayoutMetrics.calendarBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: LayoutMetrics.calendarColumns, spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 16)
            }
        }
    }

    private var monthDays: [CalendarDisplayDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let dayRange = calendar.range(of: .day, in: .month, for: month)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingDayCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let monthDayCount = dayRange.count
        let cellCount = Int(ceil(Double(leadingDayCount + monthDayCount) / 7.0)) * 7
        let firstCellDate = calendar.date(byAdding: .day, value: -leadingDayCount, to: monthInterval.start) ?? monthInterval.start

        return (0..<cellCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstCellDate) else {
                return nil
            }

            return CalendarDisplayDay(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)
            )
        }
    }

    private var normalizedRangeStartDate: Date {
        calendar.startOfDay(for: min(rangeStartDate, rangeEndDate))
    }

    private var normalizedRangeEndDate: Date {
        calendar.startOfDay(for: max(rangeStartDate, rangeEndDate))
    }

    private var isSingleDayRange: Bool {
        calendar.isDate(normalizedRangeStartDate, inSameDayAs: normalizedRangeEndDate)
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate, !isInRange(date) else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isRangeStart(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: normalizedRangeStartDate)
    }

    private func isRangeEnd(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: normalizedRangeEndDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= normalizedRangeStartDate && normalizedDate <= normalizedRangeEndDate
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

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
}

private struct WeekStripView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 14) {
            weekdayRow

            LazyVGrid(columns: LayoutMetrics.calendarColumns, spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDate = date
                        }
                    } label: {
                        CalendarDayCell(
                            date: date,
                            isSelected: isSelected(date),
                            isCurrentMonth: true,
                            isRangeStart: isRangeStart(date),
                            isRangeEnd: isRangeEnd(date),
                            isInRange: isInRange(date),
                            isSingleDayRange: isSingleDayRange,
                            isWeekStart: isWeekStart(date),
                            isWeekEnd: isWeekEnd(date),
                            continuesFromPreviousWeek: continuesFromPreviousWeek(date),
                            continuesToNextWeek: continuesToNextWeek(date),
                            calendar: calendar
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, LayoutMetrics.calendarBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: LayoutMetrics.calendarColumns, spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 16)
            }
        }
    }

    private var weekDates: [Date] {
        let focusDate = selectedDate ?? month
        let weekday = calendar.component(.weekday, from: focusDate)
        let offsetFromWeekStart = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offsetFromWeekStart, to: focusDate) ?? focusDate

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var normalizedRangeStartDate: Date {
        calendar.startOfDay(for: min(rangeStartDate, rangeEndDate))
    }

    private var normalizedRangeEndDate: Date {
        calendar.startOfDay(for: max(rangeStartDate, rangeEndDate))
    }

    private var isSingleDayRange: Bool {
        calendar.isDate(normalizedRangeStartDate, inSameDayAs: normalizedRangeEndDate)
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate, !isInRange(date) else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isRangeStart(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: normalizedRangeStartDate)
    }

    private func isRangeEnd(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: normalizedRangeEndDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= normalizedRangeStartDate && normalizedDate <= normalizedRangeEndDate
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

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isRangeStart: Bool
    let isRangeEnd: Bool
    let isInRange: Bool
    let isSingleDayRange: Bool
    let isWeekStart: Bool
    let isWeekEnd: Bool
    let continuesFromPreviousWeek: Bool
    let continuesToNextWeek: Bool
    let calendar: Calendar

    var body: some View {
        ZStack {
            rangeConnector

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 17, weight: isEmphasized ? .semibold : .regular))
                .frame(width: LayoutMetrics.calendarDayCellSize, height: LayoutMetrics.calendarDayCellSize)
                .foregroundStyle(foregroundStyle)
                .background(endpointBackground, in: Circle())
        }
            .frame(maxWidth: .infinity)
            .frame(height: LayoutMetrics.calendarDayCellSize)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(isEmphasized ? .isSelected : [])
    }

    @ViewBuilder
    private var rangeConnector: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if isInRange && !isSingleDayRange {
                    if isRangeStart {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: LayoutMetrics.calendarDayCellSize)
                        }
                    } else if isRangeEnd {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(rangeColor)
                                .frame(width: (width / 2) + 1, height: LayoutMetrics.calendarDayCellSize)
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
                .frame(height: LayoutMetrics.calendarDayCellSize)
        } else {
            Rectangle()
                .fill(rangeColor)
                .frame(height: LayoutMetrics.calendarDayCellSize)
        }
    }

    private var rangeCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: shouldRoundLeading ? LayoutMetrics.calendarDayCellSize / 2 : 0,
            bottomLeading: shouldRoundLeading ? LayoutMetrics.calendarDayCellSize / 2 : 0,
            bottomTrailing: shouldRoundTrailing ? LayoutMetrics.calendarDayCellSize / 2 : 0,
            topTrailing: shouldRoundTrailing ? LayoutMetrics.calendarDayCellSize / 2 : 0
        )
    }

    private var shouldRoundLeading: Bool {
        isWeekStart && !continuesFromPreviousWeek
    }

    private var shouldRoundTrailing: Bool {
        isWeekEnd && !continuesToNextWeek
    }

    private var rangeColor: Color {
        Color(uiColor: .systemBlue).opacity(0.14)
    }

    private var endpointBackground: Color {
        if isRangeEndpoint {
            return Color(uiColor: .systemBlue)
        }

        return isSelected ? Color.primary : Color.clear
    }

    private var isRangeEndpoint: Bool {
        isRangeStart || isRangeEnd
    }

    private var isEmphasized: Bool {
        isSelected || isRangeEndpoint
    }

    private var foregroundStyle: Color {
        if isEmphasized {
            return .white
        }

        return isCurrentMonth ? .primary : Color(uiColor: .tertiaryLabel)
    }
}

private struct CalendarDragHandle: View {
    @Binding var calendarHeight: CGFloat
    let expandedCalendarHeight: CGFloat
    let collapsedCalendarHeight: CGFloat
    let settleAnimation: Animation

    @State private var dragStartHeight: CGFloat?

    var body: some View {
        ZStack {
            Color.primary

            Capsule()
                .fill(Color.white.opacity(0.88))
                .frame(width: 42, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(settleAnimation) {
                calendarHeight = isExpanded ? collapsedCalendarHeight : expandedCalendarHeight
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    let startHeight = dragStartHeight ?? calendarHeight
                    dragStartHeight = startHeight

                    var transaction = Transaction()
                    transaction.disablesAnimations = true

                    withTransaction(transaction) {
                        calendarHeight = boundedHeight(startHeight + value.translation.height)
                    }
                }
                .onEnded { value in
                    let startHeight = dragStartHeight ?? calendarHeight
                    let projectedHeight = boundedHeight(startHeight + value.predictedEndTranslation.height)
                    let targetHeight = projectedHeight > midpoint ? expandedCalendarHeight : collapsedCalendarHeight

                    withAnimation(settleAnimation) {
                        calendarHeight = targetHeight
                        dragStartHeight = nil
                    }
                }
        )
        .accessibilityLabel("Calendar size handle")
        .accessibilityHint("Drag up to show one week. Drag down to show the month.")
    }

    private var midpoint: CGFloat {
        collapsedCalendarHeight + (expandedCalendarHeight - collapsedCalendarHeight) * 0.5
    }

    private var isExpanded: Bool {
        calendarHeight > midpoint
    }

    private func boundedHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, collapsedCalendarHeight), expandedCalendarHeight)
    }
}

private struct ScheduleGridLayout {
    let width: CGFloat
    let columnCount: Int
    let columnSpacing: CGFloat
    let columnWidth: CGFloat

    init(width: CGFloat, columnCount: Int, columnSpacing: CGFloat) {
        let normalizedColumnCount = max(columnCount, 1)
        let spacing = columnSpacing * max(CGFloat(normalizedColumnCount - 1), 0)

        self.width = width
        self.columnCount = normalizedColumnCount
        self.columnSpacing = columnSpacing
        self.columnWidth = max((width - spacing) / CGFloat(normalizedColumnCount), 0)
    }

    var columnStep: CGFloat {
        columnWidth + columnSpacing
    }

    func xOffset(for dayIndex: Int) -> CGFloat {
        CGFloat(dayIndex) * columnStep
    }

    func xCenter(for dayIndex: Int) -> CGFloat {
        xOffset(for: dayIndex) + columnWidth / 2
    }
}

private struct ScheduleGridView: View {
    let selectedDate: Date?
    let visibleDates: [Date]
    let pageIndex: Int
    let pageCount: Int
    let events: [ScheduleEvent]
    let availabilityEntries: [AvailabilitySlot: AvailabilityEntry]
    let teamResponseSummaries: [AvailabilitySlot: TeamResponseSummary]
    let isResponseMode: Bool
    let selectedAvailabilityMode: AvailabilityMode
    let rowHeight: CGFloat
    let bottomContentInset: CGFloat
    let calendar: Calendar
    let onTapSlot: (AvailabilitySlot) -> Void
    let onCommitSlots: (Set<AvailabilitySlot>) -> Void
    let onEditAvailabilityBlock: (AvailabilityBlockDetail) -> Void
    let onMovePage: (Int) -> Void

    @State private var currentTime = Date()
    @State private var dragStartSlot: AvailabilitySlot?
    @State private var dragPreviewSlots: Set<AvailabilitySlot> = []
    @State private var selectedAvailabilityBlock: AvailabilityBlockDetail?
    @State private var selectedTeamResponse: TeamResponseDetail?

    private let hours = Array(9..<18)
    private let workStartHour = 9
    private let workEndHour = 18
    private let headerHeight: CGFloat = 42
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let blockAnimation = Animation.interactiveSpring(
        response: 0.26,
        dampingFraction: 0.92,
        blendDuration: 0.04
    )
    private let dragActivationDistance: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - LayoutMetrics.horizontalPadding * 2, 0)
            let timelineWidth = max(
                contentWidth - LayoutMetrics.timeAxisWidth - LayoutMetrics.scheduleColumnSpacing,
                0
            )
            let gridLayout = ScheduleGridLayout(
                width: timelineWidth,
                columnCount: visibleDates.count,
                columnSpacing: LayoutMetrics.scheduleColumnSpacing
            )

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: LayoutMetrics.scheduleColumnSpacing) {
                    timeAxis
                        .frame(width: LayoutMetrics.timeAxisWidth)

                    VStack(spacing: 0) {
                        scheduleHeader(layout: gridLayout)
                            .frame(width: timelineWidth, height: headerHeight, alignment: .leading)

                        ZStack(alignment: .topLeading) {
                            gridBackground(layout: gridLayout)
                            if isResponseMode {
                                teamResponseLayer(layout: gridLayout)
                            } else {
                                availabilityLayer(layout: gridLayout)
                            }
                            eventLayer(layout: gridLayout)
                            currentTimeIndicator(layout: gridLayout)
                        }
                        .frame(width: timelineWidth, height: gridHeight)
                        .contentShape(Rectangle())
                        .simultaneousGesture(slotDragGesture(layout: gridLayout))
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 0)
                .padding(.bottom, bottomContentInset)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onReceive(clock) { date in
            currentTime = date
        }
        .sheet(item: $selectedAvailabilityBlock) { detail in
            AvailabilityBlockDetailSheet(
                detail: detail,
                calendar: calendar,
                onEdit: {
                    selectedAvailabilityBlock = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onEditAvailabilityBlock(detail)
                    }
                }
            )
                .presentationDetents([.height(detail.reason.isEmpty ? 260 : 320), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedTeamResponse) { detail in
            TeamResponseDetailSheet(detail: detail, calendar: calendar)
                .presentationDetents([.height(430), .medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var timeAxis: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: headerHeight)

            VStack(spacing: 3) {
                ForEach(hours, id: \.self) { hour in
                    Text(timeLabel(hour))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: LayoutMetrics.timeAxisWidth, height: rowHeight - 3, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(width: LayoutMetrics.timeAxisWidth, height: gridHeight, alignment: .topTrailing)
        }
    }

    private func scheduleHeader(layout: ScheduleGridLayout) -> some View {
        VStack(spacing: 5) {
            if pageCount > 1 {
                HStack(spacing: 8) {
                    Spacer()

                    Text("\(pageIndex + 1)/\(pageCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))

                    Button {
                        onMovePage(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex == 0)
                    .opacity(pageIndex == 0 ? 0.28 : 1)

                    Button {
                        onMovePage(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex >= pageCount - 1)
                    .opacity(pageIndex >= pageCount - 1 ? 0.28 : 1)
                }
            }

            HStack(spacing: LayoutMetrics.scheduleColumnSpacing) {
                ForEach(visibleDates, id: \.timeIntervalSinceReferenceDate) { date in
                    VStack(spacing: 1) {
                        Text(shortWeekdayText(for: date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isWeekend(date) ? Color(uiColor: .tertiaryLabel) : .secondary)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isWeekend(date) ? Color(uiColor: .tertiaryLabel) : .primary)
                    }
                    .frame(width: layout.columnWidth, height: 24)
                }
            }
        }
    }

    private func gridBackground(layout: ScheduleGridLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(visibleDates.enumerated()), id: \.element.timeIntervalSinceReferenceDate) { dayIndex, date in
                ForEach(workStartHour..<workEndHour, id: \.self) { hour in
                    let cellHeight = rowHeight - 3

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isWeekend(date) ? Color(uiColor: .systemGray6).opacity(0.54) : Color(uiColor: .systemGray6).opacity(0.72))
                        .frame(width: layout.columnWidth, height: cellHeight)
                        .position(
                            x: layout.xCenter(for: dayIndex),
                            y: yCenter(for: hour, height: cellHeight)
                        )
                }
            }
        }
        .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
    }

    private func availabilityLayer(layout: ScheduleGridLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(availabilityBlocks) { block in
                let height = CGFloat(block.endHour - block.startHour) * rowHeight - 3
                let blockWidth = layout.columnWidth
                let blockCornerRadius: CGFloat = 5

                ZStack {
                    RoundedRectangle(cornerRadius: blockCornerRadius, style: .continuous)
                        .fill(block.mode.blockFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: blockCornerRadius, style: .continuous)
                                .stroke(block.mode.blockStroke, lineWidth: 1)
                        }
                        .overlay(alignment: .topTrailing) {
                            if !block.reason.isEmpty {
                                Circle()
                                    .fill(block.mode.tint)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 7)
                                    .padding(.trailing, 7)
                            }
                        }

                    hourTicks(for: block, height: height, width: blockWidth)

                    Text(block.mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(block.mode.tint)
                }
                .frame(width: blockWidth, height: height)
                .clipped()
                .contentShape(RoundedRectangle(cornerRadius: blockCornerRadius, style: .continuous))
                .onTapGesture {
                    selectedAvailabilityBlock = detail(for: block)
                }
                .position(
                    x: layout.xCenter(for: block.dayIndex),
                    y: yCenter(for: block.startHour, height: height)
                )
                .transition(.opacity)
            }
        }
        .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
        .animation(blockAnimation, value: availabilityBlocks)
    }

    private func teamResponseLayer(layout: ScheduleGridLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(teamResponseBlocks) { block in
                let height = CGFloat(block.endHour - block.startHour) * rowHeight - 3

                ZStack {
                    Text("\(block.summary.availableCount)/\(block.summary.totalCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(block.summary.tint)
                        .monospacedDigit()

                    if block.summary.hasConcern {
                        HStack(spacing: 3) {
                            if block.summary.burdenCount > 0 {
                                Circle()
                                    .fill(Color(uiColor: .systemOrange))
                                    .frame(width: 5, height: 5)
                            }

                            if block.summary.unavailableCount > 0 {
                                Circle()
                                    .fill(Color(uiColor: .systemRed))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                    }
                }
                .frame(width: layout.columnWidth, height: height)
                .background(block.summary.fill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(block.summary.stroke, lineWidth: 1)
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(block.summary.tint)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .padding(.leading, 5)
                }
                .overlay {
                    responseHourTicks(for: block, height: height, width: layout.columnWidth)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    selectedTeamResponse = TeamResponseDetail(
                        date: block.date,
                        startHour: block.startHour,
                        endHour: block.endHour,
                        summary: block.summary
                    )
                }
                .position(
                    x: layout.xCenter(for: block.dayIndex),
                    y: yCenter(for: block.startHour, height: height)
                )
            }
        }
        .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
        .animation(blockAnimation, value: teamResponseBlocks)
    }

    @ViewBuilder
    private func responseHourTicks(for block: TeamResponseBlock, height: CGFloat, width: CGFloat) -> some View {
        let span = block.endHour - block.startHour

        if span > 1 {
            ForEach(1..<span, id: \.self) { offset in
                Rectangle()
                    .fill(Color.white.opacity(0.64))
                    .frame(width: max(width - 14, 0), height: 0.7)
                    .offset(y: CGFloat(offset) * rowHeight - height / 2)
            }
        }
    }

    @ViewBuilder
    private func eventLayer(layout: ScheduleGridLayout) -> some View {
        ForEach(eventsInVisibleDates) { event in
            let dayIndex = visibleDates.firstIndex { calendar.isDate($0, inSameDayAs: event.date) } ?? 0
            let eventHeight = max(CGFloat(event.endHour - event.startHour) * rowHeight - 8, 32)

            ScheduleEventView(event: event)
                .frame(
                    width: max(layout.columnWidth - 6, 0),
                    height: eventHeight
                )
                .position(
                    x: layout.xCenter(for: dayIndex),
                    y: yCenter(for: event.startHour, height: eventHeight) + 4
                )
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(layout: ScheduleGridLayout) -> some View {
        if let yOffset = currentTimeOffset,
           let dayIndex = currentTimeDayIndex {
            HStack(spacing: 0) {
                Circle()
                    .fill(Color(uiColor: .systemRed))
                    .frame(width: 6, height: 6)
                    .offset(x: -3)

                Rectangle()
                    .fill(Color(uiColor: .systemRed))
                    .frame(width: layout.columnWidth, height: 1)
            }
            .frame(width: layout.columnWidth, height: 6, alignment: .leading)
            .position(x: layout.xCenter(for: dayIndex), y: yOffset)
            .accessibilityLabel("Current time \(currentTimeLabel)")
        }
    }

    private func slotDragGesture(layout: ScheduleGridLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !isResponseMode else {
                    return
                }

                guard isDragging(value) else {
                    return
                }

                guard let currentSlot = slot(at: value.location, layout: layout) else {
                    return
                }

                let startSlot = dragStartSlot ?? slot(at: value.startLocation, layout: layout) ?? currentSlot
                dragStartSlot = startSlot
                let nextPreviewSlots = slots(from: startSlot, to: currentSlot)

                guard nextPreviewSlots != dragPreviewSlots else {
                    return
                }

                withAnimation(blockAnimation) {
                    dragPreviewSlots = nextPreviewSlots
                }
            }
            .onEnded { value in
                guard !isResponseMode else {
                    return
                }

                defer {
                    dragStartSlot = nil
                    withAnimation(blockAnimation) {
                        dragPreviewSlots = []
                    }
                }

                guard let endSlot = slot(at: value.location, layout: layout) else {
                    return
                }

                if isDragging(value) {
                    let startSlot = dragStartSlot ?? slot(at: value.startLocation, layout: layout) ?? endSlot
                    onCommitSlots(slots(from: startSlot, to: endSlot))
                } else if availabilityEntries[endSlot] != nil {
                    return
                } else {
                    onTapSlot(endSlot)
                }
            }
    }

    private func isDragging(_ value: DragGesture.Value) -> Bool {
        hypot(value.translation.width, value.translation.height) > dragActivationDistance
    }

    private func slot(at location: CGPoint, layout: ScheduleGridLayout) -> AvailabilitySlot? {
        guard !visibleDates.isEmpty else {
            return nil
        }

        let dayIndex = Int(location.x / layout.columnStep)
        let hourOffset = Int(location.y / rowHeight)
        let hour = workStartHour + hourOffset

        guard dayIndex >= 0, dayIndex < visibleDates.count, hour >= workStartHour, hour < workEndHour else {
            return nil
        }

        let columnStart = layout.xOffset(for: dayIndex)
        let columnEnd = columnStart + layout.columnWidth

        guard location.x >= columnStart, location.x <= columnEnd else {
            return nil
        }

        return AvailabilitySlot(date: calendar.startOfDay(for: visibleDates[dayIndex]), hour: hour)
    }

    private func slots(from startSlot: AvailabilitySlot, to endSlot: AvailabilitySlot) -> Set<AvailabilitySlot> {
        guard
            let startDayIndex = visibleDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: startSlot.date) }),
            let endDayIndex = visibleDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: endSlot.date) })
        else {
            return [endSlot]
        }

        let dayRange = min(startDayIndex, endDayIndex)...max(startDayIndex, endDayIndex)
        let hourRange = min(startSlot.hour, endSlot.hour)...max(startSlot.hour, endSlot.hour)
        var slots: Set<AvailabilitySlot> = []

        for dayIndex in dayRange {
            let date = calendar.startOfDay(for: visibleDates[dayIndex])

            for hour in hourRange where hour >= workStartHour && hour < workEndHour {
                slots.insert(AvailabilitySlot(date: date, hour: hour))
            }
        }

        return slots
    }

    private func shortWeekdayText(for date: Date) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(calendar.component(.weekday, from: date) - 1, 0)
        return symbols[min(index, symbols.count - 1)]
    }

    private var eventsInVisibleDates: [ScheduleEvent] {
        return events.filter { event in
            visibleDates.contains { date in
                calendar.isDate(event.date, inSameDayAs: date)
            }
        }
    }

    private var hourIntervalCount: Int {
        workEndHour - workStartHour
    }

    private var gridHeight: CGFloat {
        CGFloat(hourIntervalCount) * rowHeight
    }

    private var currentTimeOffset: CGFloat? {
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard
            let hour = components.hour,
            let minute = components.minute
        else {
            return nil
        }

        let decimalHour = CGFloat(hour) + CGFloat(minute) / 60
        guard decimalHour >= CGFloat(workStartHour), decimalHour <= CGFloat(workEndHour) else {
            return nil
        }

        return (decimalHour - CGFloat(workStartHour)) * rowHeight
    }

    private var currentTimeDayIndex: Int? {
        visibleDates.firstIndex { date in
            calendar.isDate(currentTime, inSameDayAs: date)
        }
    }

    private var currentTimeLabel: String {
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func timeLabel(_ hour: Int) -> String {
        "\(hour)시"
    }

    private func yCenter(for hour: Int, height: CGFloat) -> CGFloat {
        CGFloat(hour - workStartHour) * rowHeight + height / 2
    }

    @ViewBuilder
    private func hourTicks(for block: AvailabilityBlock, height: CGFloat, width: CGFloat) -> some View {
        let span = block.endHour - block.startHour

        if span > 1 {
            ForEach(1..<span, id: \.self) { offset in
                Rectangle()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: max(width - 14, 0), height: 0.7)
                    .offset(y: CGFloat(offset) * rowHeight - height / 2)
            }
        }
    }

    private func detail(for block: AvailabilityBlock) -> AvailabilityBlockDetail {
        let date = visibleDates.indices.contains(block.dayIndex) ? visibleDates[block.dayIndex] : Date()

        return AvailabilityBlockDetail(
            date: calendar.startOfDay(for: date),
            startHour: block.startHour,
            endHour: block.endHour,
            mode: block.mode,
            reason: block.reason
        )
    }

    private var availabilityBlocks: [AvailabilityBlock] {
        var blocks: [AvailabilityBlock] = []

        for (dayIndex, date) in visibleDates.enumerated() {
            var currentBlock: AvailabilityBlock?

            for hour in workStartHour..<workEndHour {
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                let entry = effectiveAvailabilityEntry(for: slot)

                guard let entry else {
                    if let currentBlock {
                        blocks.append(currentBlock)
                    }

                    currentBlock = nil
                    continue
                }

                let normalizedReason = (entry.reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if var block = currentBlock,
                   block.mode == entry.mode,
                   block.reason == normalizedReason,
                   block.endHour == hour {
                    block.endHour = hour + 1
                    currentBlock = block
                } else {
                    if let currentBlock {
                        blocks.append(currentBlock)
                    }

                    currentBlock = AvailabilityBlock(
                        dayIndex: dayIndex,
                        startHour: hour,
                        endHour: hour + 1,
                        mode: entry.mode,
                        reason: normalizedReason
                    )
                }
            }

            if let currentBlock {
                blocks.append(currentBlock)
            }
        }

        return blocks
    }

    private var teamResponseBlocks: [TeamResponseBlock] {
        var blocks: [TeamResponseBlock] = []

        for (dayIndex, date) in visibleDates.enumerated() {
            var currentBlock: TeamResponseBlock?

            for hour in workStartHour..<workEndHour {
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)

                guard let summary = teamResponseSummaries[slot] else {
                    if let currentBlock {
                        blocks.append(currentBlock)
                    }

                    currentBlock = nil
                    continue
                }

                if var block = currentBlock,
                   block.endHour == hour,
                   block.summary.mergeSignature == summary.mergeSignature {
                    block.endHour = hour + 1
                    currentBlock = block
                } else {
                    if let currentBlock {
                        blocks.append(currentBlock)
                    }

                    currentBlock = TeamResponseBlock(
                        dayIndex: dayIndex,
                        date: calendar.startOfDay(for: date),
                        startHour: hour,
                        endHour: hour + 1,
                        summary: summary
                    )
                }
            }

            if let currentBlock {
                blocks.append(currentBlock)
            }
        }

        return blocks
    }

    private func effectiveAvailabilityEntry(for slot: AvailabilitySlot) -> AvailabilityEntry? {
        if dragPreviewSlots.contains(slot) {
            if isClearingAvailablePreview {
                return nil
            }

            return AvailabilityEntry(mode: selectedAvailabilityMode, reason: nil)
        }

        return availabilityEntries[slot]
    }

    private var isClearingAvailablePreview: Bool {
        !dragPreviewSlots.isEmpty &&
            selectedAvailabilityMode == .available &&
            dragPreviewSlots.allSatisfy { availabilityEntries[$0]?.mode == .available }
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

private struct AvailabilityBlock: Identifiable, Equatable {
    let dayIndex: Int
    let startHour: Int
    var endHour: Int
    let mode: AvailabilityMode
    let reason: String

    var id: String {
        "\(dayIndex)-\(startHour)-\(mode.rawValue)-\(reason)"
    }
}

private struct TeamResponseBlock: Identifiable, Equatable {
    let dayIndex: Int
    let date: Date
    let startHour: Int
    var endHour: Int
    let summary: TeamResponseSummary

    var id: String {
        "\(dayIndex)-\(startHour)-\(endHour)-\(summary.mergeSignature)"
    }
}

private struct TeamResponseSummary: Equatable {
    let availableNames: [String]
    let burdenMembers: [TeamResponseReason]
    let unavailableMembers: [TeamResponseReason]

    var totalCount: Int {
        availableCount + burdenCount + unavailableCount
    }

    var availableCount: Int {
        availableNames.count
    }

    var burdenCount: Int {
        burdenMembers.count
    }

    var unavailableCount: Int {
        unavailableMembers.count
    }

    var caption: String {
        if unavailableCount > 0 {
            return "불가 \(unavailableCount)"
        }

        if burdenCount > 0 {
            return "부담 \(burdenCount)"
        }

        return "가능"
    }

    var hasConcern: Bool {
        burdenCount > 0 || unavailableCount > 0
    }

    var tint: Color {
        if unavailableCount >= 2 {
            return Color(uiColor: .systemRed)
        }

        if burdenCount > 0 || unavailableCount > 0 {
            return Color(uiColor: .systemOrange)
        }

        return Color(uiColor: .systemBlue)
    }

    var concernTint: Color {
        unavailableCount > 0 ? Color(uiColor: .systemRed) : Color(uiColor: .systemOrange)
    }

    var mergeSignature: String {
        let available = availableNames.sorted().joined(separator: ",")
        let burden = burdenMembers
            .map { "\($0.name):\($0.reason)" }
            .sorted()
            .joined(separator: ",")
        let unavailable = unavailableMembers
            .map { "\($0.name):\($0.reason)" }
            .sorted()
            .joined(separator: ",")

        return "\(available)|\(burden)|\(unavailable)"
    }

    var fill: Color {
        tint.opacity(0.12)
    }

    var stroke: Color {
        tint.opacity(0.24)
    }
}

private struct TeamResponseReason: Equatable, Identifiable {
    let name: String
    let reason: String

    var id: String {
        "\(name)-\(reason)"
    }
}

private struct AvailabilityBlockDetail: Identifiable {
    let id = UUID()
    let date: Date
    let startHour: Int
    let endHour: Int
    let mode: AvailabilityMode
    let reason: String
}

private struct TeamResponseDetail: Identifiable {
    let id = UUID()
    let date: Date
    let startHour: Int
    let endHour: Int
    let summary: TeamResponseSummary
}

private struct AvailabilityBlockDetailSheet: View {
    let detail: AvailabilityBlockDetail
    let calendar: Calendar
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(detail.mode.title)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(detail.mode.tint)

                        Text(dateText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(detail.mode.tint)

                        Text(timeText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(detail.mode.blockFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(detail.mode.blockStroke, lineWidth: 1)
                }

                if !detail.reason.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("사유")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(detail.reason)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 18)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("시간 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if detail.mode.requiresReason {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("편집") {
                            dismiss()
                            onEdit()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var dateText: String {
        let components = calendar.dateComponents([.month, .day], from: detail.date)
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayIndex = max(calendar.component(.weekday, from: detail.date) - 1, 0)
        let weekday = weekdaySymbols[min(weekdayIndex, weekdaySymbols.count - 1)]

        return "\(components.month ?? 0)월 \(components.day ?? 0)일 (\(weekday))"
    }

    private var timeText: String {
        "\(detail.startHour)시 - \(detail.endHour)시"
    }
}

private struct TeamResponseDetailSheet: View {
    let detail: TeamResponseDetail
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("팀원 응답")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(detail.summary.tint)

                            Text("\(dateText) · \(timeText)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(detail.summary.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(detail.summary.stroke, lineWidth: 1)
                    }

                    VStack(spacing: 10) {
                        ForEach(detail.summary.availableNames, id: \.self) { name in
                            responseMemberCard(
                                name: name,
                                status: "가능",
                                reason: "참여할 수 있어요",
                                tint: Color(uiColor: .systemGreen)
                            )
                        }

                        ForEach(detail.summary.burdenMembers) { member in
                            responseMemberCard(
                                name: member.name,
                                status: "부담",
                                reason: member.reason,
                                tint: Color(uiColor: .systemOrange)
                            )
                        }

                        ForEach(detail.summary.unavailableMembers) { member in
                            responseMemberCard(
                                name: member.name,
                                status: "불가",
                                reason: member.reason,
                                tint: Color(uiColor: .systemRed)
                            )
                        }
                    }
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("응답 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func responseMemberCard(name: String, status: String, reason: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(tint.opacity(0.72))
                .frame(width: 5)
                .padding(.vertical, 6)

            ProfileAvatar(
                name: name,
                fallback: initial(for: name),
                size: 42,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(tint.opacity(0.12), in: Capsule())
                }

                Text(reason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func initial(for name: String) -> String {
        String(name.prefix(1))
    }

    private func responseRow(title: String, detail: String, tint: Color, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, alignment: .leading)

                Text(detail.isEmpty ? "없음" : detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(detail.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 64)
            }
        }
    }

    private func responseReasonRows(title: String, members: [TeamResponseReason], tint: Color, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                HStack(alignment: .top, spacing: 12) {
                    Text(index == 0 ? title : "")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 38, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(member.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(member.reason)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if index < members.count - 1 || !isLast {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
    }

    private var dateText: String {
        let components = calendar.dateComponents([.month, .day], from: detail.date)
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayIndex = max(calendar.component(.weekday, from: detail.date) - 1, 0)
        let weekday = weekdaySymbols[min(weekdayIndex, weekdaySymbols.count - 1)]

        return "\(components.month ?? 0)월 \(components.day ?? 0)일 (\(weekday))"
    }

    private var timeText: String {
        "\(detail.startHour)시 - \(detail.endHour)시"
    }
}

private struct ScheduleEventView: View {
    let event: ScheduleEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(String(format: "%02d:00", event.startHour)) - \(String(format: "%02d:00", event.endHour))")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(uiColor: .systemGray3), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct AvailabilitySlot: Hashable {
    let date: Date
    let hour: Int
}

private struct CalendarDisplayDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool

    var id: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }
}

private struct ScheduleEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let startHour: Int
    let endHour: Int
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
