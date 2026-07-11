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
                onShareWithMembers: shareHostAvailability,
                onCompareResponses: compareCandidateTimes,
                onConfirmMeeting: confirmMeeting
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

    private func shareHostAvailability(for meetingID: String, availabilityEntries: [AvailabilitySlot: AvailabilityEntry]) {
        guard let meetingIndex = meetings.firstIndex(where: { $0.id == meetingID }) else {
            return
        }

        let updatedMeeting = meetings[meetingIndex].sharedWithMembers(hostAvailabilityEntries: availabilityEntries)
        meetings[meetingIndex] = updatedMeeting
        selectedMeeting = updatedMeeting
    }

    private func compareCandidateTimes(for meetingID: String, criteria: DerivationCriteria) {
        guard let meetingIndex = meetings.firstIndex(where: { $0.id == meetingID }) else {
            return
        }

        let updatedMeeting = meetings[meetingIndex].readyForComparison(criteria: criteria)
        meetings[meetingIndex] = updatedMeeting
        selectedMeeting = updatedMeeting
    }

    private func confirmMeeting(_ meetingID: String, candidate: FinalDerivationCandidate) {
        guard let meetingIndex = meetings.firstIndex(where: { $0.id == meetingID }) else {
            return
        }

        let updatedMeeting = meetings[meetingIndex].confirmed(
            on: candidate.slot.date,
            hour: candidate.slot.hour,
            calendar: calendar
        )
        meetings[meetingIndex] = updatedMeeting
        selectedMeeting = updatedMeeting
        selectedDate = calendar.startOfDay(for: candidate.slot.date)

        if let monthStart = calendar.dateInterval(of: .month, for: candidate.slot.date)?.start {
            displayedMonth = monthStart
        }
    }

    private func makeHomeMeeting(from draft: MeetingDraft) -> HomeMeeting {
        let candidateDates = candidateDates(from: draft.startDate, to: draft.endDate)
        let focusDate = candidateDates.first ?? draft.startDate
        return HomeMeeting(
            id: UUID().uuidString,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            sectionName: draft.sectionName,
            iconName: draft.iconName,
            subtitle: meetingSubtitle(from: draft),
            dateRange: dateRangeText(for: candidateDates),
            timeRange: draft.availabilityWindowText,
            excludedTimeRule: draft.excludedTimeRule,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: draft.members.count + 1,
            respondedCount: 0,
            status: .waiting,
            stage: .hostAvailability,
            memberInitials: ["나"] + draft.members.map(\.name),
            requiredMemberIndexes: Set([0] + draft.members.enumerated().compactMap { index, member in
                member.isRequired ? index + 1 : nil
            }),
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
    let onShareWithMembers: (String, [AvailabilitySlot: AvailabilityEntry]) -> Void
    let onCompareResponses: (String, DerivationCriteria) -> Void
    let onConfirmMeeting: (String, FinalDerivationCandidate) -> Void

    var body: some View {
        if let meeting {
            switch meeting.stage {
            case .hostAvailability, .collectingResponses, .confirmed:
                CalendarScreen(
                    selectedDate: $selectedDate,
                    displayedMonth: $displayedMonth,
                    calendarHeight: $calendarHeight,
                    expandedCalendarHeight: expandedCalendarHeight,
                    collapsedCalendarHeight: collapsedCalendarHeight,
                    events: events,
                    meeting: meeting,
                    calendar: calendar,
                    onShareWithMembers: onShareWithMembers,
                    onCompareResponses: onCompareResponses
                )
            case .bracketReview:
                BracketReviewScreen(
                    meeting: meeting,
                    onAdjustCriteria: { criteria in
                        onCompareResponses(meeting.id, criteria)
                    },
                    onConfirmMeeting: { candidate in
                        onConfirmMeeting(meeting.id, candidate)
                    }
                )
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
    static let timeAxisWidth: CGFloat = 30
    static let scheduleColumnSpacing: CGFloat = 5
    static let scheduleTrailingPadding: CGFloat = 12

    static var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 7)
    }
}

private enum SharedCalendarViewMode: String, CaseIterable, Identifiable {
    case mySchedule
    case teamResponses

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .mySchedule:
            return "내 일정"
        case .teamResponses:
            return "팀원 응답"
        }
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
    let onShareWithMembers: (String, [AvailabilitySlot: AvailabilityEntry]) -> Void
    let onCompareResponses: (String, DerivationCriteria) -> Void

    @State private var availabilityMode: AvailabilityMode = .available
    @State private var availabilityEntries: [AvailabilitySlot: AvailabilityEntry] = [:]
    @State private var reasonDraft: AvailabilityReasonDraft?
    @State private var isHostAvailabilityComplete = false
    @State private var isShareConfirmationPresented = false
    @State private var isDerivationCriteriaPresented = false
    @State private var derivationCriteria = DerivationCriteria.default
    @State private var schedulePageIndex = 0
    @State private var sharedCalendarViewMode: SharedCalendarViewMode = .teamResponses
    @State private var isDerivationTransitionActive = false
    @State private var suppressInitialTeamResponseReveal = false
    @State private var isTeamResponseRevealComplete = true

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
                    statusText: calendarStatusText
                )

                GeometryReader { proxy in
                    let calendarAnimation = Animation.interactiveSpring(
                        response: 0.42,
                        dampingFraction: 0.9,
                        blendDuration: 0.12
                    )
                    let handleBandHeight: CGFloat = 20
                    let toolbarReservedInset: CGFloat = isConfirmedCalendar ? 12 : 76
                    let clampedCalendarHeight = min(
                        max(calendarHeight, collapsedCalendarHeight),
                        expandedCalendarHeight
                    )
                    let expansionProgress = (clampedCalendarHeight - collapsedCalendarHeight) / (expandedCalendarHeight - collapsedCalendarHeight)
                    let scheduleRowHeight: CGFloat = isConfirmedCalendar ? 60 : 44
                    let scheduleHeight = max(proxy.size.height - clampedCalendarHeight - handleBandHeight, 0)

                    VStack(spacing: 0) {
                        ZStack {
                            Color.primary

                            ExpandableCalendarView(
                                month: displayedMonth,
                                selectedDate: $selectedDate,
                                rangeStartDate: meeting.candidateStartDate,
                                rangeEndDate: meeting.candidateEndDate,
                                showsDateRange: !isConfirmedCalendar,
                                eventDates: isConfirmedCalendar ? [meeting.focusDate] : [],
                                eventTint: meeting.iconTint,
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
                        .opacity(isDerivationTransitionActive ? 0 : 1)
                        .offset(y: isDerivationTransitionActive ? -74 : 0)

                        CalendarDragHandle(
                            calendarHeight: $calendarHeight,
                            expandedCalendarHeight: expandedCalendarHeight,
                            collapsedCalendarHeight: collapsedCalendarHeight,
                            settleAnimation: calendarAnimation
                        )
                        .frame(height: handleBandHeight)
                        .opacity(isDerivationTransitionActive ? 0 : 1)
                        .offset(y: isDerivationTransitionActive ? -74 : 0)

                        ZStack {
                            Color.primary

                            Group {
                                if isConfirmedCalendar {
                                    ConfirmedDayScheduleView(
                                        selectedDate: selectedDate,
                                        meeting: meeting,
                                        rowHeight: scheduleRowHeight,
                                        bottomContentInset: toolbarReservedInset,
                                        calendar: calendar
                                    )
                                } else {
                                    ScheduleGridView(
                                        selectedDate: selectedDate,
                                        visibleDates: visibleScheduleDates,
                                        pageIndex: schedulePageIndex,
                                        pageCount: scheduleDatePages.count,
                                        events: events,
                                        availabilityEntries: scheduleAvailabilityEntries,
                                        teamResponseSummaries: isViewingTeamResponses ? teamResponseSummaries : [:],
                                        excludedTimeRule: meeting.excludedTimeRule,
                                        isResponseMode: isViewingTeamResponses,
                                        animatesResponseReveal: isViewingTeamResponses && !suppressInitialTeamResponseReveal,
                                        allowsAvailabilityEditing: !isSharedCalendar,
                                        selectedAvailabilityMode: availabilityMode,
                                        rowHeight: scheduleRowHeight,
                                        bottomContentInset: toolbarReservedInset,
                                        calendar: calendar,
                                        onTapSlot: updateAvailabilitySlot,
                                        onCommitSlots: commitAvailabilitySlots,
                                        onEditAvailabilityBlock: editAvailabilityBlock,
                                        onMovePage: moveSchedulePage,
                                        onResponseRevealComplete: {
                                            isTeamResponseRevealComplete = true
                                        }
                                    )
                                }
                            }
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
                        .scaleEffect(isDerivationTransitionActive ? 1.012 : 1, anchor: .top)
                        .offset(y: isDerivationTransitionActive ? -18 : 0)
                        .opacity(isDerivationTransitionActive ? 0 : 1)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.28), value: isDerivationTransitionActive)

            Group {
                if isConfirmedCalendar {
                    EmptyView()
                } else if isSharedCalendar {
                    SharedCalendarToolbar(
                        selectedViewMode: $sharedCalendarViewMode,
                        respondedCount: displayedRespondedCount,
                        memberCount: meeting.memberCount,
                        onCompare: {
                            derivationCriteria = meeting.derivationCriteria
                            isDerivationCriteriaPresented = true
                        }
                    )
                } else {
                    AvailabilityInputToolbar(
                        selection: $availabilityMode,
                        canComplete: isAvailabilityReadyToComplete,
                        isComplete: isHostAvailabilityComplete,
                        onComplete: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.84, blendDuration: 0.04)) {
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
            .opacity(isDerivationTransitionActive ? 0 : 1)
            .offset(y: isDerivationTransitionActive ? 28 : 0)

            if isDerivationTransitionActive {
                CalendarDerivationTransitionOverlay()
                    .transition(.opacity.animation(.easeInOut(duration: 0.22)))
                    .zIndex(10)
            }
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
            .presentationDetents([.fraction(0.82)])
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
                    isTeamResponseRevealComplete = false
                    suppressInitialTeamResponseReveal = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        onShareWithMembers(meeting.id, availabilityEntries)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
                        suppressInitialTeamResponseReveal = false
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isDerivationCriteriaPresented) {
            DerivationCriteriaSheet(
                criteria: $derivationCriteria,
                onCancel: {
                    isDerivationCriteriaPresented = false
                },
                onStart: {
                    let criteria = derivationCriteria
                    isDerivationCriteriaPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        startDerivationTransition(criteria: criteria)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .toolbar(isDerivationTransitionActive ? .hidden : .visible, for: .tabBar)
    }

    private var navigationTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 2026)년 \(components.month ?? 7)월"
    }

    private var isSharedCalendar: Bool {
        meeting.stage == .collectingResponses
    }

    private var isConfirmedCalendar: Bool {
        meeting.stage == .confirmed
    }

    private var calendarStatusText: String {
        if isConfirmedCalendar {
            return "회의 확정"
        }

        return isSharedCalendar ? "팀원 응답 보기" : "내 시간 입력"
    }

    private var isViewingTeamResponses: Bool {
        isSharedCalendar && sharedCalendarViewMode == .teamResponses
    }

    private var simulatedRespondedCount: Int {
        meeting.memberCount
    }

    private var displayedRespondedCount: Int {
        guard isViewingTeamResponses else {
            return simulatedRespondedCount
        }

        return isTeamResponseRevealComplete ? simulatedRespondedCount : 0
    }

    private var scheduleAvailabilityEntries: [AvailabilitySlot: AvailabilityEntry] {
        guard isSharedCalendar, availabilityEntries.isEmpty else {
            return availabilityEntries
        }

        if !meeting.hostAvailabilityEntries.isEmpty {
            return meeting.hostAvailabilityEntries
        }

        return prototypeHostAvailabilityEntries
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
            .filter { !isExcludedSlot($0) }
        }
    }

    private var prototypeHostAvailabilityEntries: [AvailabilitySlot: AvailabilityEntry] {
        var entries: [AvailabilitySlot: AvailabilityEntry] = [:]

        for (dayIndex, date) in candidateDates.enumerated() {
            for hour in 9..<18 {
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                guard !isExcludedSlot(slot) else {
                    continue
                }

                let seed = dayIndex * 7 + hour

                if seed % 11 == 0 {
                    entries[slot] = AvailabilityEntry(mode: .unavailable, reason: "이미 잡힌 업무")
                } else if seed % 6 == 0 {
                    entries[slot] = AvailabilityEntry(mode: .burden, reason: "앞뒤 일정이 붙어 있음")
                } else {
                    entries[slot] = AvailabilityEntry(mode: .available, reason: nil)
                }
            }
        }

        return entries
    }

    private var teamResponseSummaries: [AvailabilitySlot: TeamResponseSummary] {
        TeamResponseSummary.makeSummaries(for: meeting, dates: candidateDates, calendar: calendar)
    }

    private var availabilityStateAnimation: Animation {
        .interactiveSpring(response: 0.24, dampingFraction: 0.92, blendDuration: 0.04)
    }

    private func isExcludedSlot(_ slot: AvailabilitySlot) -> Bool {
        meeting.excludedTimeRule.excludes(hour: slot.hour, date: slot.date, calendar: calendar)
    }

    private func startDerivationTransition(criteria: DerivationCriteria) {
        guard !isDerivationTransitionActive else {
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.9, blendDuration: 0.06)) {
            isDerivationTransitionActive = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            onCompareResponses(meeting.id, criteria)
        }
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

    @State private var shareButtonScale: CGFloat = 1
    @State private var completionPulseScale: CGFloat = 1
    @State private var completionPulseOpacity: Double = 0

    var body: some View {
        Group {
            if isComplete {
                Button(action: onShare) {
                    Label("공유", systemImage: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 40)
                        .background {
                            ZStack {
                                Capsule()
                                    .fill(Color(uiColor: .systemBlue))

                                Capsule()
                                    .stroke(Color(uiColor: .systemBlue).opacity(completionPulseOpacity), lineWidth: 1.3)
                                    .scaleEffect(completionPulseScale)
                            }
                        }
                }
                .buttonStyle(.plain)
                .scaleEffect(shareButtonScale)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.78).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    )
                )
            } else {
                HStack(spacing: 10) {
                    modeSegment

                    Button(action: onComplete) {
                        Label("완료", systemImage: "checkmark")
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
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity).combined(with: .move(edge: .top))
                    )
                )
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 7)
        .animation(.spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.04), value: isComplete)
        .onChange(of: isComplete) { _, newValue in
            handleCompletionTransition(isComplete: newValue)
        }
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

    private func handleCompletionTransition(isComplete: Bool) {
        guard isComplete else {
            shareButtonScale = 1
            completionPulseScale = 1
            completionPulseOpacity = 0
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        shareButtonScale = 0.9
        completionPulseScale = 1
        completionPulseOpacity = 0.38

        withAnimation(.spring(response: 0.42, dampingFraction: 0.68, blendDuration: 0.03)) {
            shareButtonScale = 1
        }

        withAnimation(.easeOut(duration: 0.62)) {
            completionPulseScale = 1.26
            completionPulseOpacity = 0
        }
    }
}

private struct SharedCalendarToolbar: View {
    @Binding var selectedViewMode: SharedCalendarViewMode

    let respondedCount: Int
    let memberCount: Int
    let onCompare: () -> Void

    private var canCompare: Bool {
        memberCount > 0 && respondedCount >= memberCount
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(SharedCalendarViewMode.allCases) { mode in
                    toolbarChip(mode.title, isSelected: selectedViewMode == mode) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                            selectedViewMode = mode
                        }
                    }
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemFill).opacity(0.72), in: Capsule())

            Button(action: onCompare) {
                ZStack {
                    Label("응답 전", systemImage: "clock")
                        .opacity(canCompare ? 0 : 1)
                        .offset(y: canCompare ? -5 : 0)

                    Label("회의 도출하기", systemImage: "sparkles")
                        .opacity(canCompare ? 1 : 0)
                        .offset(y: canCompare ? 0 : 5)
                }
                .font(.system(size: 14, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(canCompare ? .white : Color(uiColor: .tertiaryLabel))
                .frame(width: 124, height: 38)
                .background(canCompare ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray5), in: Capsule())
                .animation(.spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.04), value: canCompare)
            }
            .buttonStyle(.plain)
            .disabled(!canCompare)
            .opacity(canCompare ? 1 : 0.82)
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 7)
    }

    private var compareButtonTitle: String {
        guard !canCompare else {
            return "회의 도출하기"
        }

        if respondedCount <= 0 {
            return "응답 전"
        }

        return "\(respondedCount)/\(memberCount)"
    }

    private func toolbarChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color(uiColor: .label) : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct DerivationCriteriaSheet: View {
    @Binding var criteria: DerivationCriteria

    let onCancel: () -> Void
    let onStart: () -> Void

    @State private var isPriorityHelpPresented = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("어떤 기준으로 볼까요?")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("필참 조건을 먼저 보고, 부담과 선택 참석을 반영해요.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    criteriaCard(
                        title: "우선 시간대",
                        detail: "선호하는 시간을 더 앞에 보여줍니다."
                    ) {
                        Picker("우선 시간대", selection: $criteria.timePreference) {
                            ForEach(DerivationTimePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    criteriaCard(
                        title: "피할 시간",
                        detail: "선택한 시간은 추천에서 제외합니다."
                    ) {
                        VStack(spacing: 0) {
                            criteriaToggleRow(
                                title: "아침 첫 시간 제외",
                                detail: "9시 시작 시간을 제외합니다",
                                symbolName: "sunrise.fill",
                                isOn: $criteria.avoidsEarlyMorning
                            )

                            Divider()
                                .padding(.leading, 40)

                            criteriaToggleRow(
                                title: "점심 직후 제외",
                                detail: "13시 시작 시간을 제외합니다",
                                symbolName: "fork.knife",
                                isOn: $criteria.avoidsAfterLunch
                            )

                            Divider()
                                .padding(.leading, 40)

                            criteriaToggleRow(
                                title: "퇴근 직전 제외",
                                detail: "17시 시작 시간을 제외합니다",
                                symbolName: "moon.zzz.fill",
                                isOn: $criteria.avoidsNearLeaving
                            )
                        }
                    }

                    criteriaCard(
                        title: "추천 방식",
                        detail: "회의 성격에 맞춰 추천 순서를 조정합니다.",
                        showsPriorityHelp: true
                    ) {
                        Picker("추천 방식", selection: $criteria.priority) {
                            ForEach(DerivationDecisionPriority.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Button(action: onStart) {
                        Text("이 기준으로 도출하기")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(uiColor: .systemBlue), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
            }
        }
    }

    private func criteriaCard<Content: View>(
        title: String,
        detail: String? = nil,
        showsPriorityHelp: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let detail {
                        Text(detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if showsPriorityHelp {
                    Button {
                        isPriorityHelpPresented.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("추천 방식 설명")
                    .sheet(isPresented: $isPriorityHelpPresented) {
                        priorityHelpSheet
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var priorityHelpSheet: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("후보 조건이 비슷할 때 어떤 기준을 먼저 볼지 정합니다.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        ForEach(Array(DerivationDecisionPriority.allCases.enumerated()), id: \.element.id) { index, priority in
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: priority.symbolName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(criteria.priority == priority ? Color(uiColor: .systemBlue) : Color(uiColor: .secondaryLabel))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        (criteria.priority == priority ? Color(uiColor: .systemBlue) : Color(uiColor: .secondaryLabel))
                                            .opacity(0.1),
                                        in: Circle()
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(priority.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        if criteria.priority == priority {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color(uiColor: .systemBlue))
                                        }
                                    }

                                    Text(priority.detail)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            if index < DerivationDecisionPriority.allCases.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    burdenPriorityLegend
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("추천 방식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        isPriorityHelpPresented = false
                    }
                }
            }
        }
    }

    private var burdenPriorityLegend: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(burdenTint)
                    .frame(width: 30, height: 30)
                    .background(burdenTint.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("부담 반영 순서")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("후보가 비슷하면 부담 인원과 사유의 조정 난이도를 함께 비교합니다.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .padding(.leading, 42)

            HStack(spacing: 7) {
                burdenPriorityItem(.schedule)
                priorityOperator("=")
                burdenPriorityItem(.movement)
                priorityOperator(">")
                burdenPriorityItem(.personal)
                priorityOperator(">")
                burdenPriorityItem(.focus)
            }
            .padding(.leading, 42)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("부담 반영 순서, 일정과 이동이 가장 높고, 개인, 집중 순서")
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var burdenTint: Color {
        Color(uiColor: .systemOrange)
    }

    private func burdenPriorityItem(_ category: BurdenCategory) -> some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbolName)
                .font(.system(size: 11, weight: .semibold))

            Text(category.title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(burdenTint)
        .lineLimit(1)
    }

    private func priorityOperator(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
    }

    private func criteriaToggleRow(
        title: String,
        detail: String,
        symbolName: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .systemBlue).opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Color(uiColor: .systemBlue))
        .frame(minHeight: 58)
    }
}

private struct DerivationCriteria: Equatable {
    var timePreference: DerivationTimePreference
    var avoidsEarlyMorning: Bool
    var avoidsAfterLunch: Bool
    var avoidsNearLeaving: Bool
    var priority: DerivationDecisionPriority

    static let `default` = DerivationCriteria(
        timePreference: .any,
        avoidsEarlyMorning: false,
        avoidsAfterLunch: true,
        avoidsNearLeaving: true,
        priority: .allAvailable
    )

    func excludes(hour: Int) -> Bool {
        (avoidsEarlyMorning && hour == 9) ||
            (avoidsAfterLunch && hour == 13) ||
            (avoidsNearLeaving && hour >= 17)
    }

    func timePreferencePenalty(for hour: Int) -> Int {
        switch timePreference {
        case .any:
            return 0
        case .morning:
            return hour < 12 ? 0 : (hour - 11) * 4
        case .afternoon:
            return hour >= 13 ? 0 : (13 - hour) * 4
        }
    }

    func score(for block: DerivationResponseBlock) -> Int {
        let baseScore: Int

        switch priority {
        case .allAvailable:
            baseScore = block.availableCount * 14 - block.burdenCount * 5
        case .lowBurden:
            baseScore = block.availableCount * 10 - block.burdenCount * 10
        case .requiredFirst:
            baseScore = block.availableCount * 12 - block.unavailableCount * 18 - block.burdenCount * 4
        }

        return baseScore + block.hourSpan * 4 - timePreferencePenalty(for: block.startHour)
    }
}

private enum DerivationTimePreference: String, CaseIterable, Identifiable {
    case any
    case morning
    case afternoon

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .any:
            return "상관없음"
        case .morning:
            return "오전"
        case .afternoon:
            return "오후"
        }
    }
}

private enum DerivationDecisionPriority: String, CaseIterable, Identifiable {
    case allAvailable
    case lowBurden
    case requiredFirst

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .allAvailable:
            return "모두 참석"
        case .lowBurden:
            return "부담 적게"
        case .requiredFirst:
            return "필참 중심"
        }
    }

    var detail: String {
        switch self {
        case .allAvailable:
            return "6명 모두 가능한 시간을 먼저 추천합니다."
        case .lowBurden:
            return "가능하더라도 부담 사유가 적은 시간을 우선합니다."
        case .requiredFirst:
            return "필참 멤버가 가능한 시간을 우선합니다."
        }
    }

    var symbolName: String {
        switch self {
        case .allAvailable:
            return "person.3.fill"
        case .lowBurden:
            return "scalemass.fill"
        case .requiredFirst:
            return "checkmark.shield.fill"
        }
    }
}

private struct CalendarDerivationTransitionOverlay: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .systemBlue).opacity(0.1), in: Circle())

                Text("회의 시간을 준비하고 있어요")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("응답 블럭을 정리하는 중")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .offset(y: -18)
        }
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

private struct ReasonSuggestion: Hashable {
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

private struct CalendarHeader: View {
    let title: String

    var body: some View {
        HStack {
            headerTitle

            Spacer()

            Button {
                print("Open my profile")
            } label: {
                ProfileAvatar(
                    name: "나",
                    fallback: "나",
                    size: 34,
                    tint: Color(uiColor: .systemIndigo),
                    borderColor: Color(uiColor: .separator).opacity(0.25),
                    borderWidth: 0.8
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("내 프로필")
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

                AvatarStack(names: meeting.memberInitials, maxVisible: 4)

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
    let onAdjustCriteria: (DerivationCriteria) -> Void
    let onConfirmMeeting: (FinalDerivationCandidate) -> Void
    private let calendar: Calendar
    private let derivationSlots: [DerivationResponseSlot]
    private let responseSummaries: [AvailabilitySlot: TeamResponseSummary]

    @State private var phase: MeetingDerivationPhase = .preparing
    @State private var isDetailVisible = false
    @State private var areResponseBlocksRevealed = false
    @State private var areCriteriaExcludedSlotsDimmed = false
    @State private var areUnavailableSlotsDimmed = false
    @State private var areBurdenHeavySlotsDimmed = false
    @State private var areLowAvailabilitySlotsDimmed = false
    @State private var areNonFinalSlotsDimmed = false
    @State private var areCriteriaExcludedSlotsHidden = false
    @State private var areUnavailableSlotsHidden = false
    @State private var areBurdenHeavySlotsHidden = false
    @State private var areLowAvailabilitySlotsHidden = false
    @State private var areNonFinalSlotsHidden = false
    @State private var isRecommendationReady = false
    @State private var selectedFinalCandidateID: String?
    @State private var isEliminatedCandidatesPresented = false
    @State private var isDerivationCriteriaPresented = false
    @State private var confirmationCandidate: FinalDerivationCandidate?
    @State private var adjustedCriteria = DerivationCriteria.default
    @State private var derivationSequenceTask: Task<Void, Never>?
    @State private var phaseAnimationTask: Task<Void, Never>?

    init(
        meeting: HomeMeeting,
        onAdjustCriteria: @escaping (DerivationCriteria) -> Void,
        onConfirmMeeting: @escaping (FinalDerivationCandidate) -> Void
    ) {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ko_KR")

        let slots = DerivationResponseSlot.makeSlots(for: meeting, calendar: calendar)
        let dates = Array(Set(slots.map(\.date))).sorted()

        self.meeting = meeting
        self.onAdjustCriteria = onAdjustCriteria
        self.onConfirmMeeting = onConfirmMeeting
        self.calendar = calendar
        self.derivationSlots = slots
        self.responseSummaries = TeamResponseSummary.makeSummaries(
            for: meeting,
            dates: dates,
            calendar: calendar
        )
    }

    private enum Timing {
        static let phaseFilteringDelay = 4.8
        static let phaseComparingDelay = 9.1
        static let phaseBurdenDelay = 13.5
        static let phaseAvailabilityDelay = 17.9
        static let phaseFinalDelay = 22.4
        static let titleInitialDelay = 0.18
        static let titleCharacterInterval = 0.058
        static let titleCharacterAnimation = 0.28
        static let detailDelay = 0.38
        static let detailAnimation = 0.52
        static let blockInitialDelay = 0.7
        static let blockInterval = 0.035
        static let blockAnimationResponse = 0.44
        static let eliminationAfterDetailDelay = 0.82
        static let eliminationDimHold = 1.16
        static let eliminationDimAnimation = 0.48
        static let eliminationAnimationResponse = 0.78
        static let recommendationProcessingHold = 2.15
    }

    private var candidates: [MeetingDecisionCandidate] {
        MeetingDecisionCandidate.makeCandidates(for: meeting, calendar: calendar)
    }

    private var rankedCandidates: [MeetingDecisionCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.date < rhs.date || (calendar.isDate(lhs.date, inSameDayAs: rhs.date) && lhs.hour < rhs.hour)
            }

            return lhs.score > rhs.score
        }
    }

    private var finalCandidates: [MeetingDecisionCandidate] {
        Array(rankedCandidates.prefix(2))
    }

    private var sequenceCandidates: [MeetingDecisionCandidate] {
        MeetingDecisionCandidate.makeOnboardingGridCandidates(for: meeting, calendar: calendar)
    }

    private var criteriaReadySlots: [DerivationResponseSlot] {
        derivationSlots.filter { !meeting.derivationCriteria.excludes(hour: $0.hour) }
    }

    private var availableCandidateSlots: [DerivationResponseSlot] {
        criteriaReadySlots.filter { $0.requiredUnavailableCount == 0 }
    }

    private var burdenExclusionThreshold: Int? {
        let maxBurden = availableCandidateSlots.map(\.weightedBurdenScore).max() ?? 0
        return maxBurden > 0 ? maxBurden : nil
    }

    private var burdenReadySlots: [DerivationResponseSlot] {
        guard let burdenExclusionThreshold else {
            return availableCandidateSlots
        }

        return availableCandidateSlots.filter { $0.weightedBurdenScore < burdenExclusionThreshold }
    }

    private var minimumPreferredAvailableCount: Int? {
        let availableCounts = burdenReadySlots.map(\.availableCount)
        guard let maxAvailable = availableCounts.max(),
              let minAvailable = availableCounts.min(),
              maxAvailable > minAvailable else {
            return nil
        }

        return maxAvailable
    }

    private var highAvailabilitySlots: [DerivationResponseSlot] {
        guard let minimumPreferredAvailableCount else {
            return burdenReadySlots
        }

        return burdenReadySlots.filter { $0.availableCount >= minimumPreferredAvailableCount }
    }

    private var finalDerivationSlotIDs: Set<String> {
        Set(finalDerivationSlots.map(\.id))
    }

    private var burdenProcessSlots: [DerivationResponseSlot] {
        burdenReadySlots.isEmpty ? availableCandidateSlots : burdenReadySlots
    }

    private var availabilityProcessSlots: [DerivationResponseSlot] {
        highAvailabilitySlots.isEmpty ? burdenProcessSlots : highAvailabilitySlots
    }

    private var finalSelectionSourceSlots: [DerivationResponseSlot] {
        if !availabilityProcessSlots.isEmpty {
            return availabilityProcessSlots
        }

        if !availableCandidateSlots.isEmpty {
            return availableCandidateSlots
        }

        return criteriaReadySlots.filter { $0.requiredUnavailableCount == 0 }
    }

    private var finalDerivationSlots: [DerivationResponseSlot] {
        let rankedSlots = finalSelectionSourceSlots.sorted(by: isBetterDerivationSlot)
        let preferredSlots = rankedSlots.filter(matchesPreferredTime)
        let selectionPool = preferredSlots.isEmpty ? rankedSlots : preferredSlots

        guard let first = selectionPool.first else {
            return []
        }

        guard rankedSlots.count > 1 else {
            return [first]
        }

        let firstProfile = rankProfile(for: first)
        let diverseTiedSlot = selectionPool.dropFirst().first { slot in
            rankProfile(for: slot) == firstProfile && !calendar.isDate(slot.date, inSameDayAs: first.date)
        }
        let second = diverseTiedSlot
            ?? selectionPool.dropFirst().first
            ?? rankedSlots.first { $0.id != first.id }

        return [first, second].compactMap { $0 }
    }

    private var finalDerivationCandidates: [FinalDerivationCandidate] {
        finalDerivationSlots.enumerated().compactMap { index, slot in
            let availabilitySlot = AvailabilitySlot(date: calendar.startOfDay(for: slot.date), hour: slot.hour)
            guard let summary = responseSummaries[availabilitySlot] else {
                return nil
            }

            let presentationSummary = summary.finalCandidatePresentationSummary(rank: index)

            return FinalDerivationCandidate(
                rank: index,
                slot: slot,
                summary: presentationSummary,
                score: score(for: slot),
                rationale: finalCandidateRationale(for: slot, summary: presentationSummary, rank: index),
                timePreference: meeting.derivationCriteria.timePreference
            )
        }
    }

    private var candidateSelectionStages: [CandidateSelectionStage] {
        let criteriaExcludedSlots = removedSlots(from: derivationSlots, keeping: criteriaReadySlots)
        let requiredUnavailableSlots = removedSlots(from: criteriaReadySlots, keeping: availableCandidateSlots)
        let burdenHeavySlots = removedSlots(from: availableCandidateSlots, keeping: burdenProcessSlots)
        let lowAvailabilitySlots = removedSlots(from: burdenProcessSlots, keeping: availabilityProcessSlots)
        let rankedFinalSourceSlots = finalSelectionSourceSlots.sorted(by: isBetterDerivationSlot)
        let finalRankingSlots = removedSlots(from: rankedFinalSourceSlots, keeping: finalDerivationSlots)
        let finalRankingRationales = Dictionary(uniqueKeysWithValues: finalRankingSlots.map { slot in
            (slot.id, finalEliminationRationale(for: slot))
        })

        return [
            CandidateSelectionStage(
                kind: .criteria,
                incomingCount: derivationSlots.count,
                remainingCount: criteriaReadySlots.count,
                eliminatedSlots: criteriaExcludedSlots,
                finalCandidates: []
            ),
            CandidateSelectionStage(
                kind: .requiredAttendance,
                incomingCount: criteriaReadySlots.count,
                remainingCount: availableCandidateSlots.count,
                eliminatedSlots: requiredUnavailableSlots,
                finalCandidates: []
            ),
            CandidateSelectionStage(
                kind: .burden,
                incomingCount: availableCandidateSlots.count,
                remainingCount: burdenProcessSlots.count,
                eliminatedSlots: burdenHeavySlots,
                finalCandidates: []
            ),
            CandidateSelectionStage(
                kind: .availability,
                incomingCount: burdenProcessSlots.count,
                remainingCount: availabilityProcessSlots.count,
                eliminatedSlots: lowAvailabilitySlots,
                finalCandidates: []
            ),
            CandidateSelectionStage(
                kind: .finalRanking,
                incomingCount: finalSelectionSourceSlots.count,
                remainingCount: finalDerivationCandidates.count,
                eliminatedSlots: finalRankingSlots,
                finalCandidates: finalDerivationCandidates,
                eliminationRationales: finalRankingRationales
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SequentialDerivationTitle(
                text: phase.onboardingTitle,
                initialDelay: Timing.titleInitialDelay,
                characterInterval: Timing.titleCharacterInterval,
                characterAnimationDuration: Timing.titleCharacterAnimation
            )
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 12)

            Text(phase.onboardingDetail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 10)
                .opacity(isDetailVisible ? 1 : 0)
                .offset(y: isDetailVisible ? 0 : 8)
                .id(phase.onboardingDetail)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .animation(.easeInOut(duration: 0.38), value: isDetailVisible)

            DerivationPhaseChipRow(
                chips: phaseChips,
                isVisible: isDetailVisible
            )
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 14)

            if phase == .final && areNonFinalSlotsHidden && isRecommendationReady {
                FinalCandidateComparisonView(
                    candidates: finalDerivationCandidates,
                    selectedCandidateID: $selectedFinalCandidateID,
                    calendar: calendar,
                    selectionStageCount: candidateSelectionStages.count,
                    onShowEliminated: {
                        isEliminatedCandidatesPresented = true
                    },
                    onAdjustCriteria: {
                        adjustedCriteria = meeting.derivationCriteria
                        isDerivationCriteriaPresented = true
                    },
                    onConfirm: { candidate in
                        confirmationCandidate = candidate
                    }
                )
                .padding(.top, 24)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            } else if phase == .final && areNonFinalSlotsHidden {
                RecommendationProcessingView()
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.top, 46)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingResponseBlockStage(
                    slots: derivationSlots,
                    revealsBlocks: areResponseBlocksRevealed,
                    revealInterval: Timing.blockInterval,
                    revealAnimationResponse: Timing.blockAnimationResponse,
                    criteria: meeting.derivationCriteria,
                    dimsCriteriaExcludedSlots: areCriteriaExcludedSlotsDimmed,
                    dimsUnavailableSlots: areUnavailableSlotsDimmed,
                    dimsBurdenHeavySlots: areBurdenHeavySlotsDimmed,
                    dimsLowAvailabilitySlots: areLowAvailabilitySlotsDimmed,
                    dimsNonFinalSlots: areNonFinalSlotsDimmed,
                    hidesCriteriaExcludedSlots: areCriteriaExcludedSlotsHidden,
                    hidesUnavailableSlots: areUnavailableSlotsHidden,
                    hidesBurdenHeavySlots: areBurdenHeavySlotsHidden,
                    hidesLowAvailabilitySlots: areLowAvailabilitySlotsHidden,
                    hidesNonFinalSlots: areNonFinalSlotsHidden,
                    burdenExclusionThreshold: burdenExclusionThreshold,
                    minimumPreferredAvailableCount: minimumPreferredAvailableCount,
                    finalSlotIDs: finalDerivationSlotIDs,
                    calendar: calendar
                )
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 26)
                .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .background(Color(uiColor: .systemBackground))
        .fullScreenCover(isPresented: $isEliminatedCandidatesPresented) {
            CandidateSelectionProcessView(
                stages: candidateSelectionStages,
                responseSummaries: responseSummaries,
                initialCandidateCount: derivationSlots.count,
                calendar: calendar
            )
        }
        .fullScreenCover(item: $confirmationCandidate) { candidate in
            MeetingConfirmationSuccessView(
                meeting: meeting,
                candidate: candidate,
                calendar: calendar,
                onComplete: {
                    onConfirmMeeting(candidate)
                    confirmationCandidate = nil
                }
            )
        }
        .sheet(isPresented: $isDerivationCriteriaPresented) {
            DerivationCriteriaSheet(
                criteria: $adjustedCriteria,
                onCancel: {
                    isDerivationCriteriaPresented = false
                },
                onStart: {
                    let criteria = adjustedCriteria
                    isDerivationCriteriaPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        onAdjustCriteria(criteria)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            startDerivationSequence()
        }
        .onChange(of: meeting.id) { _, _ in
            startDerivationSequence()
        }
        .onChange(of: meeting.derivationCriteria) { _, _ in
            startDerivationSequence()
        }
        .onDisappear {
            derivationSequenceTask?.cancel()
            phaseAnimationTask?.cancel()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func removedSlots(
        from incomingSlots: [DerivationResponseSlot],
        keeping remainingSlots: [DerivationResponseSlot]
    ) -> [DerivationResponseSlot] {
        let remainingIDs = Set(remainingSlots.map(\.id))
        return incomingSlots.filter { !remainingIDs.contains($0.id) }
    }

    private func startDerivationSequence() {
        derivationSequenceTask?.cancel()
        phaseAnimationTask?.cancel()
        setPhase(.preparing)

        derivationSequenceTask = Task { @MainActor in
            guard await pause(for: Timing.phaseFilteringDelay) else {
                return
            }
            setPhase(.filtering)

            guard await pause(for: Timing.phaseComparingDelay - Timing.phaseFilteringDelay) else {
                return
            }
            setPhase(.comparing)

            guard await pause(for: Timing.phaseBurdenDelay - Timing.phaseComparingDelay) else {
                return
            }
            setPhase(.burden)

            guard await pause(for: Timing.phaseAvailabilityDelay - Timing.phaseBurdenDelay) else {
                return
            }
            setPhase(.availability)

            guard await pause(for: Timing.phaseFinalDelay - Timing.phaseAvailabilityDelay) else {
                return
            }
            setPhase(.final)
        }
    }

    private func setPhase(_ nextPhase: MeetingDerivationPhase) {
        phaseAnimationTask?.cancel()

        withAnimation(.easeInOut(duration: 0.24)) {
            phase = nextPhase
            isDetailVisible = false
            if nextPhase == .preparing {
                areResponseBlocksRevealed = false
                areCriteriaExcludedSlotsDimmed = false
                areUnavailableSlotsDimmed = false
                areBurdenHeavySlotsDimmed = false
                areLowAvailabilitySlotsDimmed = false
                areNonFinalSlotsDimmed = false
                isRecommendationReady = false
                areCriteriaExcludedSlotsHidden = false
                areUnavailableSlotsHidden = false
                areBurdenHeavySlotsHidden = false
                areLowAvailabilitySlotsHidden = false
                areNonFinalSlotsHidden = false
            }
        }

        let characterCount = nextPhase.onboardingTitle.map { _ in 1 }.count
        let detailDelay = Timing.detailDelay + Double(characterCount) * Timing.titleCharacterInterval

        phaseAnimationTask = Task { @MainActor in
            guard await pause(for: detailDelay), phase == nextPhase else {
                return
            }

            withAnimation(.easeOut(duration: Timing.detailAnimation)) {
                isDetailVisible = true
            }

            if nextPhase == .preparing {
                guard await pause(for: Timing.blockInitialDelay - Timing.detailDelay), phase == nextPhase else {
                    return
                }

                areResponseBlocksRevealed = true
                return
            }

            guard await pause(for: Timing.eliminationAfterDetailDelay), phase == nextPhase else {
                return
            }

            withAnimation(.easeInOut(duration: Timing.eliminationDimAnimation)) {
                applyDim(for: nextPhase)
            }

            guard await pause(for: Timing.eliminationDimHold), phase == nextPhase else {
                return
            }

            withAnimation(.spring(response: Timing.eliminationAnimationResponse, dampingFraction: 0.9)) {
                applyHide(for: nextPhase)
            }

            guard nextPhase == .final else {
                return
            }

            guard await pause(for: Timing.recommendationProcessingHold),
                  phase == nextPhase,
                  areNonFinalSlotsHidden else {
                return
            }

            withAnimation(.easeInOut(duration: 0.42)) {
                isRecommendationReady = true
            }
        }
    }

    private func applyDim(for phase: MeetingDerivationPhase) {
        switch phase {
        case .preparing:
            break
        case .filtering:
            areCriteriaExcludedSlotsDimmed = true
        case .comparing:
            areUnavailableSlotsDimmed = true
        case .burden:
            areBurdenHeavySlotsDimmed = true
        case .availability:
            areLowAvailabilitySlotsDimmed = true
        case .final:
            areNonFinalSlotsDimmed = true
        }
    }

    private func applyHide(for phase: MeetingDerivationPhase) {
        switch phase {
        case .preparing:
            break
        case .filtering:
            areCriteriaExcludedSlotsHidden = true
        case .comparing:
            areUnavailableSlotsHidden = true
        case .burden:
            areBurdenHeavySlotsHidden = true
        case .availability:
            areLowAvailabilitySlotsHidden = true
        case .final:
            areNonFinalSlotsHidden = true
        }
    }

    private func pause(for seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private var phaseChips: [DerivationPhaseChip] {
        switch phase {
        case .preparing:
            return [
                DerivationPhaseChip(title: "응답 \(meeting.respondedCount)/\(meeting.memberCount)", symbolName: "checkmark.circle.fill", color: Color(uiColor: .systemGreen)),
                DerivationPhaseChip(title: "검토 \(derivationSlots.count)개", symbolName: "square.grid.3x3.fill", color: Color(uiColor: .systemBlue))
            ]
        case .filtering:
            return filteringChips
        case .comparing:
            return [
                DerivationPhaseChip(title: "필참 불가 제외", symbolName: "person.crop.circle.badge.xmark.fill", color: Color(uiColor: .systemRed)),
                DerivationPhaseChip(title: "선택 불가 반영", symbolName: "minus.circle.fill", color: Color(uiColor: .systemOrange))
            ]
        case .burden:
            return [
                DerivationPhaseChip(title: burdenThresholdText, symbolName: "exclamationmark.bubble.fill", color: Color(uiColor: .systemOrange)),
                DerivationPhaseChip(title: "부담 적은 시간 우선", symbolName: "arrow.down.heart.fill", color: Color(uiColor: .systemOrange))
            ]
        case .availability:
            return [
                DerivationPhaseChip(title: availabilityThresholdText, symbolName: "person.2.fill", color: Color(uiColor: .systemGreen)),
                DerivationPhaseChip(title: "전원 참석 가능", symbolName: "checkmark.circle.fill", color: Color(uiColor: .systemGreen))
            ]
        case .final:
            var chips = [
                DerivationPhaseChip(title: "추천 + 차순위", symbolName: "sparkles", color: Color(uiColor: .systemBlue), style: .summary),
                DerivationPhaseChip(title: meeting.derivationCriteria.priority.title, symbolName: "checkmark.seal.fill", color: Color(uiColor: .systemGreen), style: .summary)
            ]

            if let preferenceChip = finalTimePreferenceChip {
                chips.append(preferenceChip)
            }

            return chips
        }
    }

    private var filteringChips: [DerivationPhaseChip] {
        var chips: [DerivationPhaseChip] = []

        if meeting.excludedTimeRule.isEnabled {
            chips.append(
                DerivationPhaseChip(
                    title: meeting.excludedTimeRule.title,
                    symbolName: "clock.badge.xmark.fill",
                    color: excludedTimeIconColor,
                    style: .criterion
                )
            )
        }

        if meeting.derivationCriteria.avoidsAfterLunch {
            chips.append(DerivationPhaseChip(title: "점심 직후 제외", symbolName: "fork.knife", color: Color(uiColor: .systemOrange), style: .criterion))
        }

        if meeting.derivationCriteria.avoidsNearLeaving {
            chips.append(DerivationPhaseChip(title: "퇴근 직전 제외", symbolName: "moon.zzz.fill", color: Color(uiColor: .systemIndigo), style: .criterion))
        }

        if meeting.derivationCriteria.avoidsEarlyMorning {
            chips.append(DerivationPhaseChip(title: "첫 시간 제외", symbolName: "sunrise.fill", color: Color(uiColor: .systemOrange), style: .criterion))
        }

        if chips.isEmpty {
            chips.append(DerivationPhaseChip(title: "기본 기준", symbolName: "slider.horizontal.3", color: Color(uiColor: .systemBlue), style: .criterion))
        }

        return Array(chips.prefix(3))
    }

    private var excludedTimeIconColor: Color {
        switch meeting.excludedTimeRule.id {
        case "lunch", "breakfast":
            return Color(uiColor: .systemOrange)
        case "dinner":
            return Color(uiColor: .systemIndigo)
        default:
            return Color(uiColor: .systemBlue)
        }
    }

    private var timePreferenceChip: DerivationPhaseChip? {
        guard meeting.derivationCriteria.timePreference != .any else {
            return nil
        }

        return DerivationPhaseChip(
            title: "\(meeting.derivationCriteria.timePreference.title) 우선 반영",
            symbolName: "clock.fill",
            color: Color(uiColor: .systemBlue),
            style: .summary
        )
    }

    private var finalTimePreferenceChip: DerivationPhaseChip? {
        guard let timePreferenceChip else {
            return nil
        }

        guard let recommendedSlot = finalDerivationSlots.first,
              matchesPreferredTime(recommendedSlot) else {
            return DerivationPhaseChip(
                title: "\(meeting.derivationCriteria.timePreference.title) 후보 없음",
                symbolName: "clock.badge.exclamationmark",
                color: Color(uiColor: .systemOrange),
                style: .summary
            )
        }

        return timePreferenceChip
    }

    private func matchesPreferredTime(_ slot: DerivationResponseSlot) -> Bool {
        switch meeting.derivationCriteria.timePreference {
        case .any:
            return true
        case .morning:
            return slot.hour < 12
        case .afternoon:
            return slot.hour >= 13
        }
    }

    private var unavailableSlotCount: Int {
        derivationSlots.filter { $0.requiredUnavailableCount > 0 }.count
    }

    private var burdenThresholdText: String {
        guard burdenExclusionThreshold != nil else {
            return "부담 응답 확인"
        }

        return "부담 응답 많은 시간 제외"
    }

    private var availabilityThresholdText: String {
        guard let minimumPreferredAvailableCount else {
            return "참석 가능성 동일"
        }

        return "\(minimumPreferredAvailableCount)명 이상 우선"
    }

    private func isBetterDerivationSlot(_ lhs: DerivationResponseSlot, _ rhs: DerivationResponseSlot) -> Bool {
        let lhsProfile = rankProfile(for: lhs)
        let rhsProfile = rankProfile(for: rhs)

        switch meeting.derivationCriteria.priority {
        case .allAvailable:
            if lhsProfile.optionalUnavailableCount != rhsProfile.optionalUnavailableCount {
                return lhsProfile.optionalUnavailableCount < rhsProfile.optionalUnavailableCount
            }
        case .lowBurden:
            if lhsProfile.burdenCount != rhsProfile.burdenCount {
                return lhsProfile.burdenCount < rhsProfile.burdenCount
            }

            if lhsProfile.weightedBurdenScore != rhsProfile.weightedBurdenScore {
                return lhsProfile.weightedBurdenScore < rhsProfile.weightedBurdenScore
            }
        case .requiredFirst:
            if lhsProfile.requiredBurdenCount != rhsProfile.requiredBurdenCount {
                return lhsProfile.requiredBurdenCount < rhsProfile.requiredBurdenCount
            }
        }

        if lhsProfile.burdenCount != rhsProfile.burdenCount {
            return lhsProfile.burdenCount < rhsProfile.burdenCount
        }

        if lhsProfile.weightedBurdenScore != rhsProfile.weightedBurdenScore {
            return lhsProfile.weightedBurdenScore < rhsProfile.weightedBurdenScore
        }

        if lhsProfile.requiredBurdenCount != rhsProfile.requiredBurdenCount {
            return lhsProfile.requiredBurdenCount < rhsProfile.requiredBurdenCount
        }

        if lhsProfile.optionalUnavailableCount != rhsProfile.optionalUnavailableCount {
            return lhsProfile.optionalUnavailableCount < rhsProfile.optionalUnavailableCount
        }

        if lhsProfile.adjacentStableSlotCount != rhsProfile.adjacentStableSlotCount {
            return lhsProfile.adjacentStableSlotCount > rhsProfile.adjacentStableSlotCount
        }

        if lhsProfile.preferencePenalty != rhsProfile.preferencePenalty {
            return lhsProfile.preferencePenalty < rhsProfile.preferencePenalty
        }

        return lhs.id < rhs.id
    }

    private func score(for slot: DerivationResponseSlot) -> Int {
        let profile = rankProfile(for: slot)
        return max(
            0,
            100 -
                profile.optionalUnavailableCount * 18 -
                profile.burdenCount * 8 -
                profile.weightedBurdenScore * 5 -
                profile.requiredBurdenCount * 6 +
                profile.adjacentStableSlotCount * 4 -
                profile.preferencePenalty
        )
    }

    private func rankProfile(for slot: DerivationResponseSlot) -> FinalCandidateRankProfile {
        let summary = responseSummary(for: slot)
        return FinalCandidateRankProfile(
            optionalUnavailableCount: summary?.optionalUnavailableCount ?? slot.optionalUnavailableCount,
            burdenCount: summary?.burdenCount ?? slot.burdenCount,
            weightedBurdenScore: summary?.weightedBurdenScore ?? slot.weightedBurdenScore,
            requiredBurdenCount: summary?.burdenMembers.filter(\.isRequired).count ?? 0,
            adjacentStableSlotCount: adjacentStableSlotCount(for: slot),
            preferencePenalty: meeting.derivationCriteria.timePreferencePenalty(for: slot.hour)
        )
    }

    private func responseSummary(for slot: DerivationResponseSlot) -> TeamResponseSummary? {
        let key = AvailabilitySlot(date: calendar.startOfDay(for: slot.date), hour: slot.hour)
        return responseSummaries[key]
    }

    private func adjacentStableSlotCount(for slot: DerivationResponseSlot) -> Int {
        [slot.hour - 1, slot.hour + 1].reduce(0) { count, hour in
            guard (9..<18).contains(hour) else {
                return count
            }

            let key = AvailabilitySlot(date: calendar.startOfDay(for: slot.date), hour: hour)
            guard let summary = responseSummaries[key],
                  summary.requiredUnavailableCount == 0,
                  summary.unavailableCount == 0 else {
                return count
            }

            return count + 1
        }
    }

    private func finalCandidateRationale(
        for slot: DerivationResponseSlot,
        summary: TeamResponseSummary,
        rank: Int
    ) -> CandidateSelectionRationale {
        let profile = rankProfile(for: slot)

        if rank == 0 {
            if meeting.derivationCriteria.timePreference != .any,
               matchesPreferredTime(slot) {
                let preferenceTitle = meeting.derivationCriteria.timePreference.title
                return CandidateSelectionRationale(
                    title: "\(preferenceTitle) 후보 중 가장 안정적",
                    detail: "주최자가 선호한 \(preferenceTitle) 시간대 중 참석 부담이 가장 낮습니다.",
                    symbolName: "clock.fill",
                    tint: Color(uiColor: .systemBlue)
                )
            }

            if summary.burdenCount == 0 {
                return CandidateSelectionRationale(
                    title: "별도 조정 없이 참석 가능",
                    detail: "필참자 불가와 부담 응답이 없어 바로 확정하기 가장 안정적인 시간입니다.",
                    symbolName: "checkmark.seal.fill",
                    tint: Color(uiColor: .systemGreen)
                )
            }

            if summary.burdenMembers.first?.category == .focus {
                return CandidateSelectionRationale(
                    title: "집중 부담 1명 확인",
                    detail: "6명 모두 참석 가능하고, 짧은 회복 시간으로 조율 가능한 부담입니다.",
                    symbolName: "brain.head.profile",
                    tint: Color(uiColor: .systemTeal)
                )
            }

            if profile.adjacentStableSlotCount > 0 {
                return CandidateSelectionRationale(
                    title: "앞뒤 일정까지 안정적",
                    detail: "회의 전후에도 참석 가능한 시간이 이어져 일정 변동에 대응하기 쉽습니다.",
                    symbolName: "calendar.badge.checkmark",
                    tint: Color(uiColor: .systemGreen)
                )
            }

            return CandidateSelectionRationale(
                title: "부담 강도가 가장 낮음",
                detail: "남은 후보 중 참석 조건과 부담 사유의 조정 위험이 가장 낮습니다.",
                symbolName: "arrow.down.heart.fill",
                tint: Color(uiColor: .systemGreen)
            )
        }

        if let firstSlot = finalDerivationSlots.first,
           let firstSummary = responseSummary(for: firstSlot)?.finalCandidatePresentationSummary(rank: 0),
           let category = summary.burdenMembers.first?.category,
           category.weight > (firstSummary.burdenMembers.first?.category.weight ?? 0) {
            return CandidateSelectionRationale(
                title: "\(category.burdenTitle)이 있어 차순위",
                detail: "전원 참석은 가능하지만 추천 시간보다 조정 위험이 큰 부담 사유가 남아 있습니다.",
                symbolName: category.symbolName,
                tint: Color(uiColor: .systemOrange)
            )
        }

        if let firstSlot = finalDerivationSlots.first {
            let firstProfile = rankProfile(for: firstSlot)

            if profile.requiredBurdenCount > firstProfile.requiredBurdenCount {
                return CandidateSelectionRationale(
                    title: "필참자 부담이 있어 차순위",
                    detail: "회의는 성립하지만 필참자의 부담 사유를 한 번 더 확인해야 합니다.",
                    symbolName: "person.crop.circle.badge.exclamationmark",
                    tint: Color(uiColor: .systemOrange)
                )
            }

            if profile.adjacentStableSlotCount < firstProfile.adjacentStableSlotCount {
                return CandidateSelectionRationale(
                    title: "앞뒤 일정 여유가 적은 대안",
                    detail: "참석 조건은 충족하지만 회의 전후에 일정 변동을 흡수할 여유가 상대적으로 적습니다.",
                    symbolName: "calendar.badge.clock",
                    tint: Color(uiColor: .systemOrange)
                )
            }

            if profile.preferencePenalty > firstProfile.preferencePenalty {
                return CandidateSelectionRationale(
                    title: "선호 시간대와 가까운 대안",
                    detail: "참석 조건은 안정적이지만 주최자가 선택한 시간 선호에서는 한 단계 뒤에 있습니다.",
                    symbolName: "clock.badge.exclamationmark",
                    tint: Color(uiColor: .systemBlue)
                )
            }

            if profile == firstProfile && !calendar.isDate(slot.date, inSameDayAs: firstSlot.date) {
                return CandidateSelectionRationale(
                    title: "동일 조건의 다른 요일 대안",
                    detail: "추천 시간과 조건이 같아 요일 선택 폭을 넓히는 대표안으로 함께 남겼습니다.",
                    symbolName: "calendar.badge.plus",
                    tint: Color(uiColor: .systemIndigo)
                )
            }
        }

        return CandidateSelectionRationale(
            title: "조건이 가장 가까운 차순위",
            detail: "추천 시간 다음으로 참석 조건과 부담 수준이 안정적인 후보입니다.",
            symbolName: "arrow.triangle.branch",
            tint: Color(uiColor: .systemIndigo)
        )
    }

    private func finalEliminationRationale(for slot: DerivationResponseSlot) -> CandidateSelectionRationale {
        guard let baselineSlot = finalDerivationSlots.last else {
            return CandidateSelectionRationale(
                title: "대표안에서 제외",
                detail: "남은 후보와 비교해 최종 대표안에는 포함되지 않았습니다.",
                symbolName: "minus.circle.fill",
                tint: Color(uiColor: .systemGray)
            )
        }

        let profile = rankProfile(for: slot)
        let baseline = rankProfile(for: baselineSlot)

        if profile.optionalUnavailableCount > baseline.optionalUnavailableCount {
            return CandidateSelectionRationale(
                title: "선택 참석자 불가 \(profile.optionalUnavailableCount)명",
                detail: "대표안보다 참석 가능한 인원이 적어 최종 두 시간에서는 제외했습니다.",
                symbolName: "person.crop.circle.badge.minus",
                tint: Color(uiColor: .systemOrange)
            )
        }

        if profile.burdenCount > baseline.burdenCount {
            return CandidateSelectionRationale(
                title: "부담 인원이 더 많음",
                detail: "대표안보다 부담 응답자가 많아 추가 조율 가능성이 높습니다.",
                symbolName: "person.2.badge.minus",
                tint: Color(uiColor: .systemOrange)
            )
        }

        if profile.weightedBurdenScore > baseline.weightedBurdenScore {
            let category = responseSummary(for: slot)?.burdenMembers.max { lhs, rhs in
                lhs.category.weight < rhs.category.weight
            }?.category
            return CandidateSelectionRationale(
                title: category.map { "\($0.burdenTitle) 조정 위험" } ?? "부담 강도가 더 높음",
                detail: "부담 인원은 같지만 일정·이동처럼 조정 위험이 큰 사유가 있어 우선순위가 낮아졌습니다.",
                symbolName: category?.symbolName ?? "exclamationmark.bubble.fill",
                tint: Color(uiColor: .systemOrange)
            )
        }

        if profile.requiredBurdenCount > baseline.requiredBurdenCount {
            return CandidateSelectionRationale(
                title: "필참자 부담",
                detail: "필참자가 참석은 가능하지만 부담을 표시해 더 안정적인 대표안을 우선했습니다.",
                symbolName: "person.crop.circle.badge.exclamationmark",
                tint: Color(uiColor: .systemOrange)
            )
        }

        if profile.adjacentStableSlotCount < baseline.adjacentStableSlotCount {
            return CandidateSelectionRationale(
                title: "앞뒤 일정 여유 부족",
                detail: "회의 전후에 전원이 가능한 시간이 적어 일정 변동에 대응하기 어렵습니다.",
                symbolName: "calendar.badge.clock",
                tint: Color(uiColor: .systemBlue)
            )
        }

        if profile.preferencePenalty > baseline.preferencePenalty {
            return CandidateSelectionRationale(
                title: "선호 시간대 우선순위 낮음",
                detail: "참석 조건은 비슷하지만 주최자가 선택한 시간 선호와 거리가 있습니다.",
                symbolName: "clock.badge.exclamationmark",
                tint: Color(uiColor: .systemBlue)
            )
        }

        if profile == baseline {
            return CandidateSelectionRationale(
                title: "동점 대표안에서 제외",
                detail: "조건이 같아 유사 시간의 중복을 줄이고 서로 다른 요일의 대표안을 남겼습니다.",
                symbolName: "equal.circle.fill",
                tint: Color(uiColor: .systemGray)
            )
        }

        return CandidateSelectionRationale(
            title: "유사 시간대 대표안에서 제외",
            detail: "참석 조건이 비슷해 선택 폭을 넓히는 대표 두 시간을 우선했습니다.",
            symbolName: "rectangle.3.group.fill",
            tint: Color(uiColor: .systemGray)
        )
    }
}

private enum MeetingDerivationPhase: Int {
    case preparing
    case filtering
    case comparing
    case burden
    case availability
    case final

    var title: String {
        switch self {
        case .preparing:
            return "응답 블럭을 검토 후보로 펼치는 중"
        case .filtering:
            return "선택 기준을 반영 중"
        case .comparing:
            return "필참 불가 시간을 제외 중"
        case .burden:
            return "부담이 큰 시간을 줄이는 중"
        case .availability:
            return "참석 가능성이 높은 시간을 남기는 중"
        case .final:
            return "추천 후보 2개가 남았어요"
        }
    }

    var detail: String {
        switch self {
        case .preparing:
            return "요일별 시간 블럭을 비교 가능한 검토 후보로 변환합니다"
        case .filtering:
            return "필참 조건과 불가 응답을 먼저 확인합니다"
        case .comparing:
            return "필참자가 불가한 시간은 제외하고, 선택 참석자 불가는 우선순위에 반영합니다"
        case .burden:
            return "참석은 가능하지만 부담이 큰 시간은 뒤로 미룹니다"
        case .availability:
            return "부담 없이 참석 가능한 팀원이 많은 시간을 우선합니다"
        case .final:
            return "시스템 추천안을 확인하고 주최자가 확정합니다"
        }
    }

    var onboardingTitle: String {
        switch self {
        case .preparing:
            return "회의 시간을 도출할게요"
        case .filtering:
            return "선택 기준을 반영할게요"
        case .comparing:
            return "필참 조건을 먼저 확인할게요"
        case .burden:
            return "부담이 큰 시간을 줄일게요"
        case .availability:
            return "참석 가능성이 높은 시간을 남길게요"
        case .final:
            return "추천 시간대를 보여줄게요"
        }
    }

    var onboardingDetail: String {
        switch self {
        case .preparing:
            return "팀원들이 입력한 시간을 검토 후보로 바꿉니다."
        case .filtering:
            return "회의 후보에서 제외할 시간을 먼저 반영합니다."
        case .comparing:
            return "선택 참석자 불가는 제외하지 않고 순위에 반영합니다."
        case .burden:
            return "불가는 아니지만 부담이 큰 시간은 우선순위를 낮춥니다."
        case .availability:
            return "남은 검토 후보 중 참석 가능성이 높은 시간을 남깁니다."
        case .final:
            return "가장 안정적인 시간을 추천해드릴게요."
        }
    }
}

private struct DerivationPhaseChip: Identifiable {
    let title: String
    let symbolName: String
    let color: Color
    var style: DerivationPhaseChipStyle = .semantic

    var id: String {
        "\(title)-\(symbolName)"
    }
}

private enum DerivationPhaseChipStyle {
    case semantic
    case criterion
    case summary
}

private extension View {
    func pillChipIcon(
        color: Color,
        size: CGFloat = 10,
        frame: CGFloat = 12
    ) -> some View {
        font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: frame, height: frame)
    }
}

private struct DerivationPhaseChipRow: View {
    let chips: [DerivationPhaseChip]
    let isVisible: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(chips.enumerated()), id: \.element.id) { index, chip in
                    DerivationPhaseChipView(chip: chip)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 7)
                        .animation(
                            .easeOut(duration: 0.28)
                                .delay(Double(index) * 0.045),
                            value: isVisible
                        )
                }
            }
            .padding(.vertical, 1)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollClipDisabled()
        .id(chips.map(\.title).joined(separator: "|"))
        .transition(.opacity.combined(with: .offset(y: 6)))
    }
}

private struct DerivationPhaseChipView: View {
    let chip: DerivationPhaseChip

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: chip.symbolName)
                .pillChipIcon(color: iconColor)

            Text(chip.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(backgroundColor, in: Capsule())
        .overlay {
            Capsule()
                .stroke(strokeColor, lineWidth: 0.7)
        }
    }

    private var textColor: Color {
        switch chip.style {
        case .semantic:
            return chip.color
        case .criterion, .summary:
            return Color(uiColor: .label)
        }
    }

    private var iconColor: Color {
        chip.color
    }

    private var backgroundColor: Color {
        switch chip.style {
        case .semantic:
            return chip.color.opacity(0.1)
        case .criterion:
            return Color(uiColor: .secondarySystemBackground)
        case .summary:
            return Color(uiColor: .secondarySystemBackground)
        }
    }

    private var strokeColor: Color {
        switch chip.style {
        case .semantic:
            return chip.color.opacity(0.12)
        case .criterion, .summary:
            return Color(uiColor: .separator).opacity(0.08)
        }
    }
}

private struct RecommendationProcessingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemBlue).opacity(0.08))

                ProgressView()
                    .controlSize(.regular)
                    .tint(Color(uiColor: .systemBlue))
            }
            .frame(width: 52, height: 52)

            Text("응답을 정리하고 있어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Text("남은 후보의 참석 가능성과 부담 사유를 비교합니다.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .accessibilityElement(children: .combine)
    }
}

private struct FinalDerivationCandidate: Identifiable {
    let rank: Int
    let slot: DerivationResponseSlot
    let summary: TeamResponseSummary
    let score: Int
    let rationale: CandidateSelectionRationale
    let timePreference: DerivationTimePreference

    var id: String {
        slot.id
    }

    var attendeeNames: [String] {
        Array((summary.availableNames + summary.burdenMembers.map(\.name)).prefix(6))
    }

    var selectionInsights: [FinalCandidateInsight] {
        var insights = [
            FinalCandidateInsight(
                title: rationale.title,
                symbolName: rationale.symbolName,
                color: rationale.tint,
                detail: rationale.detail
            )
        ]

        let rationaleExplainsPreference = timePreference != .any
            && rationale.title.contains(timePreference.title)
        let rationaleExplainsBurden = rationale.title.contains("부담")
            || rationale.title.contains("집중")

        if summary.unavailableCount > 0 && summary.requiredUnavailableCount == 0 {
            insights.append(
                FinalCandidateInsight(
                    title: "선택 \(summary.optionalUnavailableCount)명 불가",
                    symbolName: "minus.circle.fill",
                    color: Color(uiColor: .systemOrange),
                    detail: "필참자는 모두 참석 가능하며 선택 참석자의 불가 응답만 남아 있습니다."
                )
            )
        }

        if !rationaleExplainsBurden {
            insights.append(burdenInsight)
        }

        if timePreference != .any,
           timePreferencePenalty == 0,
           !rationaleExplainsPreference {
            insights.append(
                FinalCandidateInsight(
                    title: "\(timePreference.title) 선호 반영",
                    symbolName: "sun.max.fill",
                    color: Color(uiColor: .systemBlue),
                    detail: "주최자가 선택한 \(timePreference.title) 시간대 조건을 반영했습니다."
                )
            )
        }

        return Array(insights.prefix(3))
    }

    private var burdenInsight: FinalCandidateInsight {
        guard let firstBurden = summary.burdenMembers.first else {
            return FinalCandidateInsight(
                title: "부담 응답 없음",
                symbolName: "checkmark.circle.fill",
                color: Color(uiColor: .systemGreen),
                detail: "부담 응답이 없어 추가 확인 없이 확정할 수 있습니다."
            )
        }

        if summary.burdenCount == 1 {
            return FinalCandidateInsight(
                title: "\(firstBurden.category.burdenTitle) 1명 확인",
                symbolName: firstBurden.category.symbolName,
                color: Color(uiColor: .systemOrange),
                detail: "\(firstBurden.name)님의 \(firstBurden.category.burdenTitle) 응답이 있지만 참석 가능한 범위입니다."
            )
        }

        let categoryCount = Set(summary.burdenMembers.map(\.category)).count
        return FinalCandidateInsight(
            title: "부담 응답 \(summary.burdenCount)명 확인",
            symbolName: "exclamationmark.bubble.fill",
            color: Color(uiColor: .systemOrange),
            detail: "\(categoryCount)개 유형의 부담 사유를 비교해 조정 위험이 낮은 후보를 남겼습니다."
        )
    }

    private var timePreferencePenalty: Int {
        switch timePreference {
        case .any:
            return 0
        case .morning:
            return slot.hour < 12 ? 0 : 1
        case .afternoon:
            return slot.hour >= 13 ? 0 : 1
        }
    }
}

private struct FinalCandidateInsight: Identifiable, Equatable {
    let title: String
    let symbolName: String
    let color: Color
    var detail: String? = nil

    var id: String {
        title
    }
}

private struct FinalCandidateRankProfile: Equatable {
    let optionalUnavailableCount: Int
    let burdenCount: Int
    let weightedBurdenScore: Int
    let requiredBurdenCount: Int
    let adjacentStableSlotCount: Int
    let preferencePenalty: Int
}

private struct CandidateSelectionRationale {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
}

private struct CandidateSelectionStage: Identifiable {
    enum Kind: String {
        case criteria
        case requiredAttendance
        case burden
        case availability
        case finalRanking

        var title: String {
            switch self {
            case .criteria:
                return "기준 적용"
            case .requiredAttendance:
                return "필참 확인"
            case .burden:
                return "부담 비교"
            case .availability:
                return "바로 참석 비교"
            case .finalRanking:
                return "대표안 선정"
            }
        }

        var symbolName: String {
            switch self {
            case .criteria:
                return "slider.horizontal.3"
            case .requiredAttendance:
                return "person.crop.circle.badge.checkmark"
            case .burden:
                return "exclamationmark.bubble.fill"
            case .availability:
                return "person.2.fill"
            case .finalRanking:
                return "checkmark.seal.fill"
            }
        }

        var tint: Color {
            switch self {
            case .criteria:
                return Color(uiColor: .systemGray)
            case .requiredAttendance:
                return Color(uiColor: .systemRed)
            case .burden:
                return Color(uiColor: .systemOrange)
            case .availability:
                return Color(uiColor: .systemBlue)
            case .finalRanking:
                return Color(uiColor: .systemGreen)
            }
        }
    }

    let kind: Kind
    let incomingCount: Int
    let remainingCount: Int
    let eliminatedSlots: [DerivationResponseSlot]
    let finalCandidates: [FinalDerivationCandidate]
    var eliminationRationales: [String: CandidateSelectionRationale] = [:]

    var id: String {
        kind.rawValue
    }
}

private enum BorderBeamSize {
    case sm
    case md
    case line
    case pulseInner
    case pulseOutside

    var defaultBorderRadius: CGFloat {
        switch self {
        case .sm:
            return 32
        case .md, .line, .pulseInner, .pulseOutside:
            return 16
        }
    }

    var borderWidth: CGFloat {
        1
    }

    var defaultDuration: Double {
        switch self {
        case .line:
            return 3.1
        case .pulseInner, .pulseOutside:
            return 2.3
        case .sm, .md:
            return 1.96
        }
    }

    var bloomBlur: CGFloat {
        switch self {
        case .pulseOutside:
            return 13
        case .pulseInner:
            return 7
        case .line, .sm, .md:
            return 9
        }
    }
}

private enum BorderBeamColorVariant {
    case colorful
    case mono
    case ocean
    case sunset

    func colors(for theme: BorderBeamTheme) -> [Color] {
        let resolvedTheme: BorderBeamTheme = theme == .auto ? .light : theme

        switch self {
        case .colorful:
            if resolvedTheme == .light {
                return [
                    Color(red: 0.12, green: 0.62, blue: 0.68),
                    Color(red: 0.36, green: 0.70, blue: 0.50),
                    Color(red: 0.86, green: 0.62, blue: 0.24),
                    Color(red: 0.88, green: 0.26, blue: 0.43),
                    Color(red: 0.64, green: 0.28, blue: 0.78),
                    Color(red: 0.28, green: 0.42, blue: 0.86),
                    Color(red: 0.12, green: 0.62, blue: 0.68)
                ]
            } else {
                return [
                    Color(red: 0.05, green: 0.70, blue: 0.78),
                    Color(red: 0.30, green: 0.76, blue: 0.48),
                    Color(red: 0.95, green: 0.64, blue: 0.16),
                    Color(red: 0.98, green: 0.16, blue: 0.40),
                    Color(red: 0.70, green: 0.20, blue: 0.88),
                    Color(red: 0.20, green: 0.36, blue: 0.95),
                    Color(red: 0.05, green: 0.70, blue: 0.78)
                ]
            }
        case .mono:
            return [
                Color(uiColor: theme == .light ? .systemGray2 : .systemGray4),
                Color(uiColor: theme == .light ? .systemGray : .systemGray2),
                Color(uiColor: theme == .light ? .systemGray2 : .systemGray4)
            ]
        case .ocean:
            if resolvedTheme == .light {
                return [
                    Color(red: 0.18, green: 0.68, blue: 0.78),
                    Color(red: 0.20, green: 0.46, blue: 0.88),
                    Color(red: 0.36, green: 0.36, blue: 0.82),
                    Color(red: 0.58, green: 0.34, blue: 0.82),
                    Color(red: 0.18, green: 0.68, blue: 0.78)
                ]
            } else {
                return [
                    Color(uiColor: .systemCyan),
                    Color(uiColor: .systemBlue),
                    Color(uiColor: .systemIndigo),
                    Color(uiColor: .systemPurple),
                    Color(uiColor: .systemCyan)
                ]
            }
        case .sunset:
            if resolvedTheme == .light {
                return [
                    Color(red: 0.88, green: 0.52, blue: 0.20),
                    Color(red: 0.86, green: 0.72, blue: 0.24),
                    Color(red: 0.84, green: 0.34, blue: 0.62),
                    Color(red: 0.86, green: 0.30, blue: 0.28),
                    Color(red: 0.88, green: 0.52, blue: 0.20)
                ]
            } else {
                return [
                    Color(uiColor: .systemOrange),
                    Color(uiColor: .systemYellow),
                    Color(uiColor: .systemPink),
                    Color(uiColor: .systemRed),
                    Color(uiColor: .systemOrange)
                ]
            }
        }
    }
}

private enum BorderBeamTheme {
    case dark
    case light
    case auto
}

private struct BorderBeamThemePreset {
    let strokeOpacity: Double
    let innerOpacity: Double
    let bloomOpacity: Double
    let brightness: Double
    let saturation: Double

    static func preset(size: BorderBeamSize, theme: BorderBeamTheme) -> BorderBeamThemePreset {
        let resolvedTheme: BorderBeamTheme = theme == .auto ? .light : theme

        switch (size, resolvedTheme) {
        case (.pulseOutside, .dark):
            return BorderBeamThemePreset(strokeOpacity: 0.94, innerOpacity: 0.34, bloomOpacity: 0.30, brightness: 1.9, saturation: 1.2)
        case (.pulseOutside, _):
            return BorderBeamThemePreset(strokeOpacity: 0.32, innerOpacity: 0.10, bloomOpacity: 0.56, brightness: 1.18, saturation: 0.82)
        case (.pulseInner, .dark):
            return BorderBeamThemePreset(strokeOpacity: 1.0, innerOpacity: 0.44, bloomOpacity: 0.66, brightness: 0.75, saturation: 1.2)
        case (.pulseInner, _):
            return BorderBeamThemePreset(strokeOpacity: 0.32, innerOpacity: 0.40, bloomOpacity: 0.80, brightness: 1.3, saturation: 0.75)
        case (.sm, .dark):
            return BorderBeamThemePreset(strokeOpacity: 0.46, innerOpacity: 0.24, bloomOpacity: 0.38, brightness: 1.3, saturation: 1.2)
        case (.sm, _):
            return BorderBeamThemePreset(strokeOpacity: 0.12, innerOpacity: 0.30, bloomOpacity: 0.16, brightness: 1.3, saturation: 1.8)
        case (.line, .dark):
            return BorderBeamThemePreset(strokeOpacity: 1.0, innerOpacity: 0.70, bloomOpacity: 0.80, brightness: 1.3, saturation: 1.2)
        case (.line, _):
            return BorderBeamThemePreset(strokeOpacity: 0.16, innerOpacity: 0.32, bloomOpacity: 0.30, brightness: 1.3, saturation: 1.95)
        case (.md, .dark):
            return BorderBeamThemePreset(strokeOpacity: 0.26, innerOpacity: 0.42, bloomOpacity: 0.24, brightness: 1.3, saturation: 1.2)
        case (.md, _):
            return BorderBeamThemePreset(strokeOpacity: 0.12, innerOpacity: 0.26, bloomOpacity: 0.34, brightness: 1.3, saturation: 1.5)
        }
    }
}

private struct BorderBeamModifier: ViewModifier {
    let active: Bool
    let size: BorderBeamSize
    let colorVariant: BorderBeamColorVariant
    let theme: BorderBeamTheme
    let strength: Double
    let duration: Double?
    let borderRadius: CGFloat?
    let brightness: Double?
    let saturation: Double?
    let hueRange: Double
    let staticColors: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedRadius: CGFloat {
        borderRadius ?? size.defaultBorderRadius
    }

    private var resolvedDuration: Double {
        duration ?? size.defaultDuration
    }

    private var clampedStrength: Double {
        min(max(strength, 0), 1)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if active && size == .pulseOutside {
                    pulseLayer(showBloom: true, showStroke: true)
                }
            }
            .overlay {
                if active && size != .pulseOutside {
                    pulseLayer(showBloom: true, showStroke: true)
                }
            }
    }

    @ViewBuilder
    private func pulseLayer(showBloom: Bool, showStroke: Bool) -> some View {
        let preset = BorderBeamThemePreset.preset(size: size, theme: theme)
        let finalBrightness = brightness ?? preset.brightness
        let colors = colorVariant.colors(for: theme)
        let shape = RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)

        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let rawProgress = reduceMotion ? 0.65 : pulseProgress(at: timeline.date)
            let linearProgress = reduceMotion ? 0.18 : cycleProgress(at: timeline.date)
            let breath = 0.50 + rawProgress * 0.50
            let opacity = clampedStrength * breath
            let gradient = AngularGradient(
                colors: colors,
                center: .center,
                angle: .degrees(staticColors ? 0 : linearProgress * 360)
            )

            ZStack {
                if showBloom && size == .pulseOutside {
                    shape
                        .stroke(gradient, lineWidth: outsideBloomLineWidth)
                        .blur(radius: 5.2)
                        .scaleEffect(1.006 + rawProgress * 0.003)
                        .opacity(min(1, preset.bloomOpacity * opacity * finalBrightness))
                }

                if showStroke {
                    shape
                        .stroke(gradient, lineWidth: crispStrokeWidth)
                        .opacity(min(1, preset.strokeOpacity * opacity * finalBrightness))
                        .blur(radius: size == .pulseOutside ? 0.45 : 0)
                }

                if showBloom && size != .pulseOutside {
                    shape
                        .stroke(gradient, lineWidth: size.borderWidth + 2.5)
                        .blur(radius: size == .pulseInner ? 4.7 : 6.5)
                        .opacity(min(1, preset.innerOpacity * opacity * finalBrightness))
                        .blendMode(.screen)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var crispStrokeWidth: CGFloat {
        switch size {
        case .pulseOutside:
            return 0.72
        case .pulseInner:
            return size.borderWidth + 0.8
        case .sm, .md, .line:
            return size.borderWidth + 0.8
        }
    }

    private var outsideBloomLineWidth: CGFloat {
        switch size {
        case .pulseOutside:
            return size.borderWidth + 3.2
        case .pulseInner:
            return size.borderWidth + 3
        case .sm, .md, .line:
            return size.borderWidth + 3.5
        }
    }

    private func pulseProgress(at date: Date) -> Double {
        let position = cycleProgress(at: date)
        return (sin(position * .pi * 2 - .pi / 2) + 1) / 2
    }

    private func cycleProgress(at date: Date) -> Double {
        let cycle = max(resolvedDuration, 0.1)
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
    }
}

private extension View {
    func borderBeam(
        active: Bool = true,
        size: BorderBeamSize = .md,
        colorVariant: BorderBeamColorVariant = .colorful,
        theme: BorderBeamTheme = .dark,
        strength: Double = 1,
        duration: Double? = nil,
        borderRadius: CGFloat? = nil,
        brightness: Double? = nil,
        saturation: Double? = nil,
        hueRange: Double = 30,
        staticColors: Bool = false
    ) -> some View {
        modifier(
            BorderBeamModifier(
                active: active,
                size: size,
                colorVariant: colorVariant,
                theme: theme,
                strength: strength,
                duration: duration,
                borderRadius: borderRadius,
                brightness: brightness,
                saturation: saturation,
                hueRange: hueRange,
                staticColors: staticColors
            )
        )
    }
}

private struct FinalCandidateComparisonView: View {
    let candidates: [FinalDerivationCandidate]
    @Binding var selectedCandidateID: String?
    let calendar: Calendar
    let selectionStageCount: Int
    let onShowEliminated: () -> Void
    let onAdjustCriteria: () -> Void
    let onConfirm: (FinalDerivationCandidate) -> Void
    @State private var detailCandidate: FinalDerivationCandidate?
    @State private var didRevealCandidates = false
    @State private var didCompleteCandidateIntro = false

    private var selectedCandidate: FinalDerivationCandidate? {
        candidates.first { $0.id == selectedCandidateID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    ForEach(Array(candidates.prefix(2).enumerated()), id: \.element.id) { index, candidate in
                        FinalCandidateDetailCard(
                            candidate: candidate,
                            calendar: calendar,
                            isSelected: didCompleteCandidateIntro && selectedCandidateID == candidate.id,
                            onSelect: {
                                guard didCompleteCandidateIntro else {
                                    return
                                }

                                if selectedCandidateID == candidate.id {
                                    detailCandidate = candidate
                                } else {
                                    selectCandidate(candidate)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .opacity(didRevealCandidates ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 0.46)
                                .delay(0.10 + Double(index) * 0.16),
                            value: didRevealCandidates
                        )
                    }
                }
                .padding(.vertical, 2)
                .animation(.spring(response: 0.56, dampingFraction: 0.92, blendDuration: 0.14), value: didCompleteCandidateIntro)

                Button(action: onShowEliminated) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("후보 선별 과정")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("제외된 이유와 최종 후보를 확인합니다")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text("\(selectionStageCount)단계")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.08), lineWidth: 0.7)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .opacity(didRevealCandidates ? 1 : 0)
                .offset(y: didRevealCandidates ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.25), value: didRevealCandidates)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)

            Spacer(minLength: 20)

            HStack(spacing: 12) {
                Button(action: onAdjustCriteria) {
                    Text("기준 조정")
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity)

                Button {
                    guard let selectedCandidate else {
                        return
                    }

                    onConfirm(selectedCandidate)
                } label: {
                    Text(confirmButtonTitle)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(selectedCandidateID == nil ? Color(uiColor: .tertiarySystemFill) : Color(uiColor: .systemBlue))
                .disabled(selectedCandidateID == nil)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.bottom, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            didRevealCandidates = false
            didCompleteCandidateIntro = false

            if selectedCandidateID == nil {
                selectedCandidateID = candidates.first?.id
            }

            withAnimation(.easeInOut(duration: 0.38).delay(0.04)) {
                didRevealCandidates = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
                withAnimation(.interactiveSpring(response: 0.48, dampingFraction: 0.9, blendDuration: 0.08)) {
                    didCompleteCandidateIntro = true
                }
            }
        }
        .sheet(item: $detailCandidate) { candidate in
            FinalCandidateDetailSheet(
                candidate: candidate,
                calendar: calendar
            )
            .presentationDetents([.large])
            .presentationBackground(Color(uiColor: .systemGroupedBackground))
            .presentationDragIndicator(.visible)
        }
    }

    private var confirmButtonTitle: String {
        guard let selectedCandidate else {
            return "후보를 선택해 주세요"
        }

        return selectedCandidate.rank == 0 ? "추천 시간 확정" : "다른 시간 확정"
    }

    private func selectCandidate(_ candidate: FinalDerivationCandidate) {
        withAnimation(.spring(response: 0.56, dampingFraction: 0.92, blendDuration: 0.14)) {
            selectedCandidateID = candidate.id
        }
    }
}

private struct MeetingConfirmationSuccessView: View {
    let meeting: HomeMeeting
    let candidate: FinalDerivationCandidate
    let calendar: Calendar
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var isTitleVisible = false
    @State private var isSummaryVisible = false
    @State private var isActionVisible = false
    @State private var confettiTrigger = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var showBeam = false
    @State private var beamOpacity = 0.0
    @State private var beamVisibilityTask: Task<Void, Never>?

    private let successTint = Color(uiColor: .systemGreen)

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                AnimatedConfirmationCheckmark(
                    circleProgress: circleProgress,
                    checkProgress: checkProgress,
                    tint: successTint
                )
                .frame(width: 94, height: 94)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("회의가 확정됐어요")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(meeting.memberCount)명의 조율 결과를 반영했습니다.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .opacity(isTitleVisible ? 1 : 0)
                .offset(y: isTitleVisible ? 0 : 8)

                confirmationSummary
                    .padding(.top, 30)
                    .opacity(isSummaryVisible ? 1 : 0)
                    .offset(y: isSummaryVisible ? 0 : 10)

                Spacer(minLength: 34)

                Button(action: onComplete) {
                    Text("완료")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(Color(uiColor: .systemBlue))
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.bottom, 10)
                .opacity(isActionVisible ? 1 : 0)
                .offset(y: isActionVisible ? 0 : 8)
                .disabled(!isActionVisible)
            }

            CelebrationConfettiView(
                trigger: confettiTrigger,
                isEnabled: !reduceMotion
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .onAppear(perform: startConfirmationAnimation)
        .onDisappear {
            animationTask?.cancel()
            beamVisibilityTask?.cancel()
        }
    }

    private var confirmationSummary: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 10) {
                Text(meeting.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Spacer(minLength: 8)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.slot.fullDateText(calendar: calendar))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(candidate.slot.timeRangeText)
                    .font(.system(size: 31, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }

            Divider()

            HStack(spacing: 8) {
                Label(confirmedMetaText, systemImage: confirmedMetaSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)

                Spacer(minLength: 10)

                AvatarStack(
                    names: meeting.memberInitials,
                    maxVisible: 3,
                    size: 26,
                    borderColor: Color(uiColor: .systemBackground),
                    borderWidth: 2.2,
                    overlap: 8
                )

                Text("\(meeting.memberCount)명 참석")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(minHeight: 28)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: confirmationCardRadius, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: confirmationCardRadius, style: .continuous)
                        .fill(Color(uiColor: .systemBlue).opacity(0.035))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: confirmationCardRadius, style: .continuous)
                .stroke(Color(uiColor: .systemBlue).opacity(0.22), lineWidth: 0.8)
        }
        .borderBeam(
            active: showBeam,
            size: .pulseOutside,
            colorVariant: .colorful,
            theme: .light,
            strength: 0.70 * beamOpacity,
            duration: 3.8,
            borderRadius: confirmationCardRadius,
            brightness: 1.14,
            saturation: 0.82,
            hueRange: 360
        )
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
    }

    private var confirmationCardRadius: CGFloat {
        22
    }

    private var confirmedPlaceText: String? {
        let components = meeting.subtitle
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let modeIndex = components.firstIndex(where: { $0 == "온라인" || $0 == "오프라인" }) else {
            return nil
        }

        if components[modeIndex] == "온라인" {
            return "온라인"
        }

        let locationIndex = components.index(after: modeIndex)
        return locationIndex < components.endIndex ? components[locationIndex] : "오프라인"
    }

    private var confirmedPlaceSymbolName: String {
        confirmedPlaceText == "온라인" ? "video.fill" : "mappin.and.ellipse"
    }

    private var confirmedMetaText: String {
        confirmedPlaceText ?? meeting.sectionName
    }

    private var confirmedMetaSymbolName: String {
        confirmedPlaceText == nil ? "person.3.fill" : confirmedPlaceSymbolName
    }

    private func startConfirmationAnimation() {
        animationTask?.cancel()
        circleProgress = 0
        checkProgress = 0
        isTitleVisible = false
        isSummaryVisible = false
        isActionVisible = false
        confettiTrigger = 0
        showBeam = false
        beamOpacity = 0
        beamVisibilityTask?.cancel()

        guard !reduceMotion else {
            circleProgress = 1
            checkProgress = 1
            isTitleVisible = true
            isSummaryVisible = true
            isActionVisible = true
            showBeam = true
            beamOpacity = 1
            return
        }

        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.72)) {
                circleProgress = 1
            }

            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.48)) {
                checkProgress = 1
            }

            try? await Task.sleep(nanoseconds: 330_000_000)
            guard !Task.isCancelled else { return }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            confettiTrigger += 1

            withAnimation(.easeOut(duration: 0.42)) {
                isTitleVisible = true
            }

            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.46)) {
                isSummaryVisible = true
            }
            scheduleBeamAppearance()

            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.38)) {
                isActionVisible = true
            }
        }
    }

    private func scheduleBeamAppearance() {
        beamVisibilityTask?.cancel()
        beamVisibilityTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(0.42))
                try Task.checkCancellation()
            } catch {
                return
            }

            showBeam = true
            beamOpacity = 0
            withAnimation(.easeOut(duration: 0.62)) {
                beamOpacity = 1
            }
        }
    }
}

private struct AnimatedConfirmationCheckmark: View {
    let circleProgress: CGFloat
    let checkProgress: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.08 * checkProgress))

            Circle()
                .stroke(tint.opacity(0.12), lineWidth: 4)

            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            ConfirmationCheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .padding(24)
        }
        .scaleEffect(0.96 + checkProgress * 0.04)
    }
}

private struct ConfirmationCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.82))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.18))
        return path
    }
}

private struct CelebrationConfettiView: UIViewRepresentable {
    let trigger: Int
    let isEnabled: Bool

    func makeUIView(context: Context) -> CelebrationConfettiCanvas {
        CelebrationConfettiCanvas()
    }

    func updateUIView(_ uiView: CelebrationConfettiCanvas, context: Context) {
        uiView.setEmissionToken(isEnabled ? trigger : 0)
    }
}

private final class CelebrationConfettiCanvas: UIView {
    private enum ThreadsConfettiStyle {
        case circle
        case rectangle
    }

    private struct ThreadsConfettiParticle {
        let container: CATransformLayer
    }

    private var lastEmissionToken = 0
    private var pendingEmissionToken = 0
    private var activeParticleLayers: [CALayer] = []
    private var cleanupWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playIfNeeded()
    }

    func setEmissionToken(_ token: Int) {
        guard token > lastEmissionToken else {
            return
        }

        pendingEmissionToken = token
        setNeedsLayout()
        playIfNeeded()
    }

    private func playIfNeeded() {
        guard pendingEmissionToken > lastEmissionToken,
              bounds.width > 0,
              bounds.height > 0 else {
            return
        }

        lastEmissionToken = pendingEmissionToken
        cleanupWorkItem?.cancel()
        activeParticleLayers.forEach {
            $0.removeAllAnimations()
            $0.removeFromSuperlayer()
        }
        activeParticleLayers.removeAll()

        let particleCountPerSide = 24

        for side in 0..<2 {
            for index in 0..<particleCountPerSide {
                let particle = makeParticle(side: side, index: index)
                let animation = makeParticleAnimation(
                    side: side,
                    index: index,
                    size: bounds.size
                )

                layer.addSublayer(particle.container)
                particle.container.add(animation, forKey: "threads.confetti")
                activeParticleLayers.append(particle.container)
            }
        }

        let cleanup = DispatchWorkItem { [weak self] in
            self?.activeParticleLayers.forEach {
                $0.removeAllAnimations()
                $0.removeFromSuperlayer()
            }
            self?.activeParticleLayers.removeAll()
        }
        cleanupWorkItem = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1, execute: cleanup)
    }

    private func makeParticle(side: Int, index: Int) -> ThreadsConfettiParticle {
        var random = DeterministicConfettiRandom(seed: seed(side: side, index: index))
        let color = Self.palette[(index + side * 3) % Self.palette.count]
        let container = CATransformLayer()
        container.opacity = 0

        switch particleStyle(for: index) {
        case .circle:
            let diameter = random.value(in: 10.2...14.6)
            container.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            addSolidFaces(
                to: container,
                color: color,
                cornerRadius: diameter / 2
            )
            return ThreadsConfettiParticle(container: container)

        case .rectangle:
            let isCompact = index % 4 == 2
            let width = random.value(in: 8.6...13.2)
            let height = isCompact
                ? random.value(in: 11.5...16.8)
                : random.value(in: 16.5...24.5)
            container.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            addSolidFaces(
                to: container,
                color: color,
                cornerRadius: min(width, height) * 0.12
            )
            return ThreadsConfettiParticle(container: container)
        }
    }

    private func addSolidFaces(
        to container: CATransformLayer,
        color: UIColor,
        cornerRadius: CGFloat
    ) {
        let back = makeSolidFace(
            bounds: container.bounds,
            color: Self.backFaceColor,
            cornerRadius: cornerRadius,
            isBackFace: true
        )
        let front = makeSolidFace(
            bounds: container.bounds,
            color: color,
            cornerRadius: cornerRadius,
            isBackFace: false
        )
        container.addSublayer(back)
        container.addSublayer(front)
    }

    private func makeSolidFace(
        bounds: CGRect,
        color: UIColor,
        cornerRadius: CGFloat,
        isBackFace: Bool
    ) -> CALayer {
        let face = CALayer()
        face.frame = bounds
        face.backgroundColor = color.cgColor
        face.cornerRadius = cornerRadius
        face.isDoubleSided = false

        if isBackFace {
            face.borderColor = UIColor.black.withAlphaComponent(0.055).cgColor
            face.borderWidth = 0.35
            face.transform = backFaceTransform
        }
        return face
    }

    private var backFaceTransform: CATransform3D {
        var transform = CATransform3DMakeRotation(.pi, 0, 1, 0)
        transform = CATransform3DTranslate(transform, 0, 0, 0.02)
        return transform
    }

    private func makeParticleAnimation(
        side: Int,
        index: Int,
        size: CGSize
    ) -> CAAnimationGroup {
        var random = DeterministicConfettiRandom(seed: seed(side: side, index: index) ^ 0xA5A5_A5A5)
        let direction: CGFloat = side == 0 ? 1 : -1
        let startX: CGFloat = side == 0 ? -16 : size.width + 16
        let verticalBand = (index * 5 + side * 3) % 8
        let verticalBandStart = 0.04 + CGFloat(verticalBand) * 0.1
        let verticalBandEnd = min(verticalBandStart + 0.08, 0.82)
        let startY = size.height * random.value(in: verticalBandStart...verticalBandEnd)
        let duration = random.value(in: 1.82...2.48)
        let delay = random.value(in: 0...0.18)
        let travelFractionRange: ClosedRange<CGFloat>
        switch index % 6 {
        case 0:
            travelFractionRange = 0.12...0.28
        case 1, 4:
            travelFractionRange = 0.28...0.5
        case 2, 5:
            travelFractionRange = 0.5...0.72
        default:
            travelFractionRange = 0.72...0.96
        }
        let horizontalTravel = size.width * random.value(in: travelFractionRange)
        let verticalVelocity = random.value(in: -132...82)
        let gravity = random.value(in: 94...158)
        let waveAmplitude = random.value(in: 3...12)
        let waveFrequency = random.value(in: 2.6...5.2)
        let wavePhase = random.value(in: 0...(CGFloat.pi * 2))
        let rotationDirection: CGFloat = random.nextUnit() > 0.5 ? 1 : -1
        let rotationTurns = random.value(in: 1.5...3.6) * rotationDirection
        let flipDirection: CGFloat = random.nextUnit() > 0.5 ? 1 : -1
        let flipTurns = random.value(in: 1.35...3.2) * flipDirection
        let initialRotation = random.value(in: 0...(CGFloat.pi * 2))
        let initialFlip = random.value(in: 0...(CGFloat.pi * 2))
        let sampleCount = 42
        let keyTimes = (0..<sampleCount).map {
            NSNumber(value: Double($0) / Double(sampleCount - 1))
        }
        let points: [CGPoint] = (0..<sampleCount).map { sampleIndex in
            let progress = CGFloat(sampleIndex) / CGFloat(sampleCount - 1)
            let elapsed = duration * progress
            let horizontalProgress = 1 - exp(-2.25 * elapsed)
            let wave = sin(elapsed * waveFrequency + wavePhase) * waveAmplitude * progress
            let x = startX + direction * horizontalTravel * horizontalProgress + wave
            let y = startY + verticalVelocity * elapsed + 0.5 * gravity * elapsed * elapsed
            return CGPoint(x: x, y: y)
        }

        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = points.map(NSValue.init(cgPoint:))
        position.keyTimes = keyTimes
        position.calculationMode = .linear
        position.duration = duration

        let transform = CAKeyframeAnimation(keyPath: "transform")
        transform.values = (0..<sampleCount).map { sampleIndex in
            let progress = CGFloat(sampleIndex) / CGFloat(sampleCount - 1)
            let zAngle = initialRotation + rotationTurns * .pi * 2 * progress
            let yAngle = initialFlip + flipTurns * .pi * 2 * progress
            let scale = 0.86 + sin(progress * .pi) * 0.16 - progress * 0.08

            var value = CATransform3DIdentity
            value.m34 = -1 / 500
            value = CATransform3DRotate(value, zAngle, 0, 0, 1)
            value = CATransform3DRotate(value, yAngle, 0, 1, 0)
            value = CATransform3DScale(value, scale, scale, scale)
            return NSValue(caTransform3D: value)
        }
        transform.keyTimes = keyTimes
        transform.calculationMode = .linear
        transform.duration = duration

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0.68, 0]
        opacity.keyTimes = [0, 0.03, 0.55, 0.82, 1]
        opacity.duration = duration

        let group = CAAnimationGroup()
        group.animations = [position, transform, opacity]
        group.beginTime = CACurrentMediaTime() + delay
        group.duration = duration
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        return group
    }

    private func particleStyle(for index: Int) -> ThreadsConfettiStyle {
        switch index % 6 {
        case 0, 4:
            return .circle
        default:
            return .rectangle
        }
    }

    private func seed(side: Int, index: Int) -> UInt64 {
        UInt64(7_919 + side * 10_007 + index * 1_009)
    }

    private static let palette: [UIColor] = [
        UIColor(red: 1.00, green: 0.02, blue: 0.45, alpha: 1),
        UIColor(red: 0.83, green: 0.04, blue: 0.79, alpha: 1),
        UIColor(red: 0.48, green: 0.23, blue: 0.98, alpha: 1),
        UIColor(red: 1.00, green: 0.81, blue: 0.02, alpha: 1),
        UIColor(red: 1.00, green: 0.43, blue: 0.04, alpha: 1),
        UIColor(red: 0.96, green: 0.14, blue: 0.22, alpha: 1),
        UIColor(red: 1.00, green: 0.43, blue: 0.66, alpha: 1),
        UIColor(red: 0.78, green: 0.73, blue: 0.82, alpha: 1)
    ]

    private static let backFaceColor = UIColor(white: 0.97, alpha: 1)
}

private struct DeterministicConfettiRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = max(seed, 1)
    }

    mutating func nextUnit() -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let value = Double(state >> 11) / Double(1 << 53)
        return CGFloat(value)
    }

    mutating func value(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
    }
}

private struct FinalCandidateDetailCard: View {
    let candidate: FinalDerivationCandidate
    let calendar: Calendar
    let isSelected: Bool
    let onSelect: () -> Void

    private var tint: Color {
        candidate.rank == 0 ? Color(uiColor: .systemBlue) : Color(uiColor: .systemIndigo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSelected ? 15 : 9) {
            headerRow

            if isSelected {
                VStack(alignment: .leading, spacing: 15) {
                    expandedTimeSummary
                    recommendationReason
                    Divider()
                    participantSummary
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            } else {
                collapsedSummary
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
        .background {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(baseCardBackground)
                .overlay {
                    if candidate.rank == 0 {
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .fill(cardTintOverlay)
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(cardStroke, lineWidth: isSelected ? 0.8 : 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .onTapGesture {
            onSelect()
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Label(candidate.rank == 0 ? "추천 시간" : "다른 가능한 시간", systemImage: candidate.rank == 0 ? "sparkles" : "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            } else {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
    }

    private var expandedTimeSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(candidate.slot.fullDateText(calendar: calendar))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(candidate.slot.timeRangeText)
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recommendationReason: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: candidate.rationale.symbolName)
                .font(.system(size: 15, weight: candidate.rank == 0 ? .semibold : .bold))
                .symbolRenderingMode(candidate.rank == 0 ? .hierarchical : .monochrome)
                .foregroundStyle(candidate.rationale.tint)
                .frame(width: 28, height: 28)
                .background(reasonIconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.rank == 0 ? "가장 안정적인 이유" : "차순위로 남은 이유")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(comparisonReasonText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }

            Spacer(minLength: 0)
        }
    }

    private var collapsedSummary: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(headerTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 5) {
                    Image(systemName: riskSymbolName)
                        .font(.system(size: 10, weight: .bold))

                    Text(riskSummaryText)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(riskTint)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardRadius: CGFloat {
        22
    }

    private var baseCardBackground: Color {
        candidate.rank == 0
            ? Color(uiColor: .systemBackground)
            : Color(uiColor: .secondarySystemBackground)
    }

    private var cardTintOverlay: Color {
        tint.opacity(isSelected ? 0.035 : 0.022)
    }

    private var cardStroke: Color {
        if candidate.rank == 0 {
            return tint.opacity(isSelected ? 0.22 : 0.12)
        }

        return isSelected ? tint.opacity(0.18) : Color(uiColor: .separator).opacity(0.08)
    }

    private var headerTitle: String {
        return "\(candidate.slot.collapsedDateText(calendar: calendar)) \(candidate.slot.timeText)"
    }

    private var comparisonReasonText: String {
        candidate.rationale.title
    }

    private var participantSummary: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarStack(
                names: candidate.attendeeNames,
                maxVisible: 3,
                size: 28,
                borderColor: Color(uiColor: .systemBackground),
                borderWidth: 2.4,
                overlap: 8
            )

            Spacer(minLength: 10)

            HStack(spacing: 5) {
                Text(attendanceCompactText)
                    .foregroundStyle(.primary)

                Text("·")
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))

                Text(riskSummaryText)
                    .foregroundStyle(riskTint)
            }
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
    }

    private var attendanceCompactText: String {
        let attendableCount = candidate.summary.availableCount + candidate.summary.burdenCount

        if attendableCount == candidate.summary.totalCount {
            return "\(candidate.summary.totalCount)명 모두 참석"
        }

        return "\(attendableCount)/\(candidate.summary.totalCount)명 참석"
    }

    private var riskSummaryText: String {
        if candidate.summary.unavailableCount > 0 {
            return "선택 \(candidate.summary.optionalUnavailableCount)명 불가"
        }

        if let category = candidate.summary.burdenMembers.first?.category {
            return "\(category.burdenTitle) \(candidate.summary.burdenCount)명"
        }

        return "부담 없음"
    }

    private var riskTint: Color {
        if candidate.summary.unavailableCount > 0 {
            return Color(uiColor: .systemRed)
        }

        if candidate.summary.burdenCount > 0 {
            return Color(uiColor: .systemOrange)
        }

        return Color(uiColor: .systemGreen)
    }

    private var riskSymbolName: String {
        if candidate.summary.unavailableCount > 0 {
            return "minus.circle.fill"
        }

        if candidate.summary.burdenCount > 0 {
            return "exclamationmark.bubble.fill"
        }

        return "checkmark.circle.fill"
    }

    private var reasonIconBackground: Color {
        candidate.rationale.tint.opacity(0.1)
    }
}

private struct FinalCandidateInsightPillRow: View {
    let insights: [FinalCandidateInsight]
    var maxVisible: Int = 3
    var axis: Axis = .vertical

    var body: some View {
        if axis == .horizontal {
            HStack(spacing: 6) {
                insightPills
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                insightPills
            }
        }
    }

    @ViewBuilder
    private var insightPills: some View {
        ForEach(Array(insights.prefix(maxVisible))) { insight in
            HStack(spacing: 4) {
                Image(systemName: insight.symbolName)
                    .pillChipIcon(color: insight.color)

                Text(insight.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(insight.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(insight.color.opacity(0.1), in: Capsule())
        }
    }
}

private struct FinalCandidateSummaryPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(tint.opacity(0.1), in: Capsule())
    }
}

private struct FinalCandidateDetailSheet: View {
    let candidate: FinalDerivationCandidate
    let calendar: Calendar
    @Environment(\.dismiss) private var dismiss
    @State private var isInsightExpanded = true
    @State private var isParticipantExpanded = false
    @State private var isBurdenExpanded = true
    @State private var isUnavailableExpanded = false

    private var tint: Color {
        candidate.rank == 0 ? Color(uiColor: .systemBlue) : Color(uiColor: .systemIndigo)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryHeader

                    accordionSection(
                        title: candidate.rank == 0 ? "추천 근거" : "차순위 근거",
                        subtitle: "\(candidate.selectionInsights.count)개 기준 반영",
                        symbolName: "sparkles",
                        tint: Color(uiColor: .systemBlue),
                        isExpanded: $isInsightExpanded
                    ) {
                        VStack(spacing: 8) {
                            ForEach(candidate.selectionInsights) { insight in
                                insightReasonRow(insight)
                            }
                        }
                    }

                    accordionSection(
                        title: "참석자",
                        subtitle: "필참 \(candidate.summary.requiredTotalCount)명 · 선택 \(candidate.summary.optionalTotalCount)명",
                        symbolName: "person.3.sequence.fill",
                        tint: Color(uiColor: .systemGreen),
                        isExpanded: $isParticipantExpanded
                    ) {
                        detailInnerCard(verticalPadding: 4, horizontalPadding: 10) {
                            VStack(spacing: 0) {
                                ForEach(Array(attendeeRows.enumerated()), id: \.offset) { index, row in
                                    attendeeRow(row)

                                    if index < attendeeRows.count - 1 {
                                        Divider()
                                            .padding(.leading, 46)
                                    }
                                }
                            }
                        }
                    }

                    if !candidate.summary.burdenMembers.isEmpty {
                        accordionSection(
                            title: "확인할 부담",
                            subtitle: burdenAccordionSubtitle,
                            symbolName: "exclamationmark.bubble.fill",
                            tint: Color(uiColor: .systemOrange),
                            isExpanded: $isBurdenExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(candidate.summary.burdenMembers) { member in
                                    reasonDetailRow(member: member, status: "부담", tint: Color(uiColor: .systemOrange))
                                }
                            }
                        }
                    }

                    if !candidate.summary.unavailableMembers.isEmpty {
                        accordionSection(
                            title: "불가 응답",
                            subtitle: unavailableAccordionSubtitle,
                            symbolName: "xmark.circle.fill",
                            tint: Color(uiColor: .systemRed),
                            isExpanded: $isUnavailableExpanded
                        ) {
                            VStack(spacing: 10) {
                                ForEach(candidate.summary.unavailableMembers) { member in
                                    reasonDetailRow(member: member, status: "불가", tint: Color(uiColor: .systemRed))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("시간 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(candidate.rank == 0 ? "추천 시간" : "차순위 시간")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(tint.opacity(0.1), in: Capsule())

                Spacer(minLength: 0)

                Text("응답 \(candidate.summary.totalCount)명")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.slot.fullDateText(calendar: calendar))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(candidate.slot.timeRangeText)
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: candidate.rank == 0 ? "checkmark.seal.fill" : "arrow.triangle.branch")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(candidate.rank == 0 ? Color(uiColor: .systemGreen) : tint)

                Text(candidateVerdictText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                summaryStatusPill(
                    title: "참석",
                    count: candidate.summary.availableCount + candidate.summary.burdenCount,
                    tint: Color(uiColor: .systemGreen)
                )

                summaryStatusPill(
                    title: "부담",
                    count: candidate.summary.burdenCount,
                    tint: Color(uiColor: .systemOrange)
                )

                summaryStatusPill(
                    title: "불가",
                    count: candidate.summary.unavailableCount,
                    tint: Color(uiColor: .systemRed)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.08), lineWidth: 0.7)
        }
    }

    private var burdenAccordionSubtitle: String {
        guard let first = candidate.summary.burdenMembers.first else {
            return "확인할 응답 없음"
        }

        if candidate.summary.burdenCount == 1 {
            return "\(first.name) · \(first.category.burdenTitle)"
        }

        return "\(candidate.summary.burdenCount)명 사유 확인"
    }

    private var unavailableAccordionSubtitle: String {
        candidate.summary.unavailableCount == 0 ? "불가 응답 없음" : "\(candidate.summary.unavailableCount)명 확인"
    }

    private var attendeeRows: [FinalCandidateAttendeeRowModel] {
        let availableRows = candidate.summary.availableNames.map { name in
            FinalCandidateAttendeeRowModel(
                name: name,
                status: "가능",
                tint: Color(uiColor: .systemGreen),
                isRequired: candidate.summary.requiredAvailableNames.contains(name)
            )
        }

        let burdenRows = candidate.summary.burdenMembers.map { member in
            FinalCandidateAttendeeRowModel(
                name: member.name,
                status: "부담",
                tint: Color(uiColor: .systemOrange),
                isRequired: member.isRequired
            )
        }

        let unavailableRows = candidate.summary.unavailableMembers.map { member in
            FinalCandidateAttendeeRowModel(
                name: member.name,
                status: "불가",
                tint: Color(uiColor: .systemRed),
                isRequired: member.isRequired
            )
        }

        return (availableRows + burdenRows + unavailableRows).sorted { lhs, rhs in
            if lhs.isRequired != rhs.isRequired {
                return lhs.isRequired && !rhs.isRequired
            }

            if attendeeStatusOrder(lhs.status) != attendeeStatusOrder(rhs.status) {
                return attendeeStatusOrder(lhs.status) < attendeeStatusOrder(rhs.status)
            }

            return lhs.name < rhs.name
        }
    }

    private var candidateVerdictText: String {
        if candidate.rank == 0 {
            if candidate.summary.burdenCount == 0 {
                return "모두 참석할 수 있고 별도 조정이 필요 없어요."
            }

            return "모두 참석할 수 있고 후보 중 부담이 가장 적어요."
        }

        if candidate.summary.unavailableCount > 0 {
            return "필참자는 가능하지만 선택 참석자 조정이 필요해요."
        }

        return "모두 참석할 수 있지만 부담 사유를 확인해야 해요."
    }

    private func attendeeStatusOrder(_ status: String) -> Int {
        switch status {
        case "가능":
            return 0
        case "부담":
            return 1
        default:
            return 2
        }
    }

    private func summaryStatusPill(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text("\(title) \(count)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(tint.opacity(count == 0 ? 0.06 : 0.12), in: Capsule())
    }

    private func accordionSection<Content: View>(
        title: String,
        subtitle: String,
        symbolName: String,
        tint: Color,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: isExpanded.wrappedValue ? 12 : 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.92, blendDuration: 0.05)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.1), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.08), lineWidth: 0.7)
        }
    }

    private func insightReasonRow(_ insight: FinalCandidateInsight) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(insight.color)
                .frame(width: 28, height: 28)
                .background(insight.color.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(insightDetailText(for: insight))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func attendeeRow(_ row: FinalCandidateAttendeeRowModel) -> some View {
        HStack(spacing: 10) {
            ProfileAvatar(
                name: row.name,
                fallback: ProfileAsset.fallbackText(for: row.name),
                size: 34,
                tint: row.tint
            )

            HStack(spacing: 4) {
                Text(row.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                if row.isRequired {
                    Text("· 필참")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("· 선택")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(row.status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(row.tint)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(row.tint.opacity(0.1), in: Capsule())
        }
        .frame(height: 48)
    }

    private func detailInnerCard<Content: View>(
        verticalPadding: CGFloat = 12,
        horizontalPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.1), lineWidth: 0.7)
        }
    }

    private func reasonDetailRow(member: TeamResponseReason, status: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(tint.opacity(0.76))
                .frame(width: 5)
                .padding(.vertical, 5)

            ProfileAvatar(
                name: member.name,
                fallback: ProfileAsset.fallbackText(for: member.name),
                size: 40,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 7) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    reasonStatusChip(member: member, status: status, tint: tint)

                    Spacer(minLength: 0)
                }

                Text(member.displayReason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.1), lineWidth: 0.7)
        }
    }

    private func reasonStatusChip(member: TeamResponseReason, status: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: status == "부담" ? member.category.symbolName : "xmark.circle.fill")
                .pillChipIcon(color: tint)

            Text(status == "부담" ? member.category.burdenTitle : status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(tint.opacity(0.1), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func insightDetailText(for insight: FinalCandidateInsight) -> String {
        if let detail = insight.detail {
            return detail
        }

        switch insight.title {
        case "전원 참석 가능":
            return "불가 응답 없이 6명이 모두 참석 가능한 후보입니다."
        case "필참 전원 가능":
            return "필수 참석자가 모두 가능한 시간이라 회의 성립 조건을 충족합니다."
        case "부담 없음":
            return "참석 가능 응답만 있어 별도 조정 리스크가 낮습니다."
        case "부담 낮음":
            return "부담 응답은 있지만 사유의 강도가 낮아 조율 가능한 범위입니다."
        case "오후 선호 반영":
            return "주최자가 선호한 오후 시간대 조건에 맞는 후보입니다."
        case let title where title.hasPrefix("선택 "):
            return "필참자는 모두 참석 가능하며 선택 참석자의 불가 응답만 남아 있습니다."
        case let title where title.hasPrefix("부담 "):
            if let category = candidate.summary.burdenMembers.first?.category {
                return "\(category.burdenTitle) 응답이 있지만 참석 가능한 범위로 판단했습니다."
            }

            return "참석은 가능하지만 확인이 필요한 부담 응답이 있습니다."
        case "업무 시간 적합":
            return "아침, 점심 직후, 퇴근 전 시간을 피한 업무 시간대입니다."
        default:
            return "응답 기준에 따라 추천 우선순위에 반영된 항목입니다."
        }
    }
}

private struct FinalCandidateAttendeeRowModel {
    let name: String
    let status: String
    let tint: Color
    let isRequired: Bool
}

private struct FinalBurdenCategoryPillRow: View {
    let summaries: [BurdenCategorySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(summaries.prefix(2)) { summary in
                HStack(spacing: 4) {
                    Image(systemName: summary.category.symbolName)
                        .pillChipIcon(color: summary.category.color)

                    Text("\(summary.category.title) \(summary.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(summary.category.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 8)
                .frame(height: 25)
                .background(summary.category.color.opacity(0.1), in: Capsule())
            }
        }
    }
}

private struct FinalCandidateReasonRow: View {
    let member: TeamResponseReason
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            ProfileAvatar(
                name: member.name,
                fallback: ProfileAsset.fallbackText(for: member.name),
                size: 26,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(member.reason)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CandidateSelectionProcessView: View {
    let stages: [CandidateSelectionStage]
    let responseSummaries: [AvailabilitySlot: TeamResponseSummary]
    let initialCandidateCount: Int
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStageID: CandidateSelectionStage.ID?

    private var finalCandidateCount: Int {
        stages.last?.remainingCount ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                processSummary
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.top, 12)

                stagePicker
                    .padding(.top, 18)

                GeometryReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(stages) { stage in
                                CandidateSelectionStagePage(
                                    stage: stage,
                                    responseSummaries: responseSummaries,
                                    calendar: calendar
                                )
                                .frame(width: max(proxy.size.width - 64, 280))
                                .frame(height: proxy.size.height)
                                .id(stage.id)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedStageID)
                }
                .padding(.top, 14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("후보 선별 과정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("추천안으로 돌아가기")
                }
            }
        }
        .onAppear {
            if selectedStageID == nil {
                selectedStageID = stages.first?.id
            }
        }
    }

    private var processSummary: some View {
        Text("\(initialCandidateCount)개 중 \(finalCandidateCount)개를 추천했어요")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.primary)
            .monospacedDigit()
    }

    private var stagePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(stages) { stage in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                selectedStageID = stage.id
                                proxy.scrollTo(stage.id, anchor: .center)
                            }
                        } label: {
                            Text(stage.kind.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedStageID == stage.id ? Color.white : Color(uiColor: .secondaryLabel))
                                .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                selectedStageID == stage.id ? Color.primary : Color(uiColor: .systemBackground),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        selectedStageID == stage.id
                                            ? Color.clear
                                            : Color(uiColor: .separator).opacity(0.18),
                                        lineWidth: 0.7
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .id(stage.id)
                    }
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedStageID) { _, newValue in
                guard let newValue else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

private struct CandidateSelectionStagePage: View {
    let stage: CandidateSelectionStage
    let responseSummaries: [AvailabilitySlot: TeamResponseSummary]
    let calendar: Calendar

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                stageHeader
                countFlow
                    .padding(.top, 18)

                Divider()
                    .overlay(Color(uiColor: .separator).opacity(0.12))
                    .padding(.top, 18)
                    .padding(.bottom, 18)

                if stage.kind == .finalRanking {
                    finalCandidateSection
                } else {
                    eliminatedSection
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.08), lineWidth: 0.7)
        }
    }

    private var stageHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: stage.kind.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(stage.kind.tint)
                .frame(width: 34, height: 34)
                .background(stage.kind.tint.opacity(0.1), in: Circle())

            Text(stageOutcomeText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.92)
                .layoutPriority(1)

            Spacer(minLength: 4)
        }
    }

    private var stageOutcomeText: String {
        let removedCount = stage.eliminatedSlots.count

        switch stage.kind {
        case .criteria:
            return removedCount == 0
                ? "주최자 기준 · 제외 없음"
                : "주최자 기준 · \(removedCount)개 제외"
        case .requiredAttendance:
            return removedCount == 0
                ? "필참 불가 · 제외 없음"
                : "필참 불가 · \(removedCount)개 제외"
        case .burden:
            return removedCount == 0
                ? "부담 높음 · 제외 없음"
                : "부담 높음 · \(removedCount)개 제외"
        case .availability:
            return removedCount == 0
                ? "바로 참석 적음 · 제외 없음"
                : "바로 참석 적음 · \(removedCount)개 제외"
        case .finalRanking:
            return "안정적인 \(stage.remainingCount)개 추천"
        }
    }

    private var countFlow: some View {
        HStack(alignment: .center, spacing: 0) {
            CandidateSelectionCountMetric(
                count: stage.incomingCount,
                label: "검토 후보",
                tint: Color(uiColor: .secondaryLabel)
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .frame(width: 38)

            CandidateSelectionCountMetric(
                count: stage.remainingCount,
                label: stage.kind == .finalRanking ? "추천 후보" : "남은 후보",
                tint: stage.kind.tint
            )
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var eliminatedSection: some View {
        if stage.eliminatedSlots.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemGreen))

                Text("이 단계에서 제외된 후보가 없어요")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 14)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                connectedEliminatedRows
            }
        }
    }

    private var connectedEliminatedRows: some View {
        LazyVStack(spacing: 10) {
            ForEach(sortedEliminatedSlots) { slot in
                CandidateSelectionSlotRow(
                    slot: slot,
                    stageKind: stage.kind,
                    summary: summary(for: slot),
                    selectionRationale: stage.eliminationRationales[slot.id],
                    calendar: calendar
                )
            }
        }
    }

    private var finalCandidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(stage.finalCandidates) { candidate in
                CandidateSelectionFinalRow(candidate: candidate, calendar: calendar)
            }

            if !stage.eliminatedSlots.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("마지막 비교에서 내려간 후보")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(stage.eliminatedSlots.count)개")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                connectedEliminatedRows
            }
        }
    }

    private var sortedEliminatedSlots: [DerivationResponseSlot] {
        if stage.kind == .finalRanking {
            return stage.eliminatedSlots
        }

        return stage.eliminatedSlots.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.hour < rhs.hour
            }

            return lhs.date < rhs.date
        }
    }

    private func summary(for slot: DerivationResponseSlot) -> TeamResponseSummary? {
        let key = AvailabilitySlot(date: calendar.startOfDay(for: slot.date), hour: slot.hour)
        return responseSummaries[key]
    }
}

private struct CandidateSelectionCountMetric: View {
    let count: Int
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(height: 29, alignment: .center)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(height: 14, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct CandidateSelectionExcludedRowHeader: View {
    let dateText: String
    let timeText: String
    let reasonText: String
    let tint: Color
    let showsChevron: Bool
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(dateText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(timeText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 14)
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(reasonText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct CandidateSelectionSlotRow: View {
    let slot: DerivationResponseSlot
    let stageKind: CandidateSelectionStage.Kind
    let summary: TeamResponseSummary?
    let selectionRationale: CandidateSelectionRationale?
    let calendar: Calendar
    @State private var isExpanded = false

    private var canExpand: Bool {
        guard summary != nil else {
            return false
        }

        switch stageKind {
        case .requiredAttendance, .burden, .availability:
            return true
        case .finalRanking:
            return selectionRationale != nil
        case .criteria:
            return false
        }
    }

    private var reasonTint: Color {
        selectionRationale?.tint ?? stageKind.tint
    }

    private var reasonText: String {
        switch stageKind {
        case .criteria:
            if slot.hour == 9 {
                return "아침 시간 제외"
            }

            if slot.hour == 13 {
                return "점심 직후 제외"
            }

            if slot.hour >= 17 {
                return "퇴근 전 시간 제외"
            }

            return "선택 기준에서 제외"
        case .requiredAttendance:
            return requiredAttendanceReasonText
        case .burden:
            return burdenReasonText
        case .availability:
            return availabilityReasonText
        case .finalRanking:
            return compactFinalReasonText
        }
    }

    private var requiredAttendanceReasonText: String {
        let members = summary?.unavailableMembers.filter(\.isRequired) ?? []
        guard let first = members.first else {
            return "필참 불가"
        }

        if members.count == 1 {
            return "\(first.name) · 필참 불가"
        }

        return "\(first.name) 외 \(members.count - 1)명 · 필참 불가"
    }

    private var burdenReasonText: String {
        let members = summary?.burdenMembers ?? []
        guard let first = members.first else {
            return "부담 사유 확인"
        }

        let categories = Set(members.map(\.category))
        let categoryText = categories.count == 1
            ? first.category.burdenTitle
            : "부담 유형 \(categories.count)개"

        if members.count == 1 {
            return "\(first.name) · \(categoryText)"
        }

        return "\(first.name) 외 \(members.count - 1)명 · \(categoryText)"
    }

    private var availabilityReasonText: String {
        let totalCount = slot.availableCount + slot.burdenCount + slot.unavailableCount
        let reviewCount = max(totalCount - slot.availableCount, 0)

        guard reviewCount > 0 else {
            return "\(slot.availableCount)/\(totalCount) 바로 가능"
        }

        return "\(slot.availableCount)/\(totalCount) 바로 가능 · \(reviewCount)명 확인"
    }

    private var compactFinalReasonText: String {
        guard let title = selectionRationale?.title else {
            return "대표안에서 제외"
        }

        switch title {
        case "선호 시간대 우선순위 낮음":
            return "선호 시간대 후순위"
        case "동점 대표안에서 제외":
            return "동점 대표안 중복"
        case "유사 시간대 대표안에서 제외":
            return "유사 시간대 중복"
        default:
            return title
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard canExpand else {
                    return
                }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.92, blendDuration: 0.05)) {
                    isExpanded.toggle()
                }
            } label: {
                CandidateSelectionExcludedRowHeader(
                    dateText: slot.collapsedDateText(calendar: calendar),
                    timeText: slot.timeRangeText,
                    reasonText: reasonText,
                    tint: reasonTint,
                    showsChevron: canExpand,
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(.plain)

            if canExpand && isExpanded {
                Divider()
                    .padding(.leading, 12)

                expandedDetails
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.1), lineWidth: 0.7)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.92, blendDuration: 0.05), value: isExpanded)
    }

    @ViewBuilder
    private var expandedDetails: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 10) {
                if stageKind == .finalRanking, let expandedSummaryMessage {
                    CandidateSelectionDetailMessage(
                        text: expandedSummaryMessage.text,
                        symbolName: expandedSummaryMessage.symbolName,
                        tint: expandedSummaryMessage.tint
                    )
                }

                if stageKind == .availability {
                    availabilityBreakdown(summary)
                }

                let issues = responseIssues(from: summary)
                if issues.isEmpty && stageKind != .finalRanking {
                    CandidateSelectionDetailMessage(
                        text: "다른 후보보다 부담 없이 참석 가능한 인원이 적어요.",
                        symbolName: "person.2.fill",
                        tint: stageKind.tint
                    )
                } else {
                    ForEach(issues) { issue in
                        CandidateSelectionIssueRow(issue: issue)
                    }
                }
            }
        }
    }

    private var expandedSummaryMessage: (text: String, symbolName: String, tint: Color)? {
        guard summary != nil else {
            return nil
        }

        switch stageKind {
        case .criteria:
            return nil
        case .requiredAttendance:
            return (
                "필참자가 불가해 6명 모두 참석하는 조건을 충족하지 못했어요.",
                "person.crop.circle.badge.xmark",
                Color(uiColor: .systemRed)
            )
        case .burden:
            return (
                "부담 인원과 사유의 조정 난이도를 함께 비교해 우선순위를 낮췄어요.",
                "exclamationmark.bubble.fill",
                Color(uiColor: .systemOrange)
            )
        case .availability:
            return (
                "바로 참석 가능한 인원이 더 많은 후보를 우선했어요.",
                "person.2.fill",
                Color(uiColor: .systemBlue)
            )
        case .finalRanking:
            guard let selectionRationale else {
                return nil
            }

            return (selectionRationale.detail, selectionRationale.symbolName, selectionRationale.tint)
        }
    }

    private func availabilityBreakdown(_ summary: TeamResponseSummary) -> some View {
        HStack(spacing: 8) {
            CandidateSelectionResponseCount(
                title: "가능",
                count: summary.availableCount,
                tint: Color(uiColor: .systemGreen)
            )

            CandidateSelectionResponseCount(
                title: "부담",
                count: summary.burdenCount,
                tint: Color(uiColor: .systemOrange)
            )

            CandidateSelectionResponseCount(
                title: "불가",
                count: summary.unavailableCount,
                tint: Color(uiColor: .systemRed)
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func responseIssues(from summary: TeamResponseSummary) -> [CandidateSelectionIssue] {
        switch stageKind {
        case .requiredAttendance:
            return summary.unavailableMembers
                .filter(\.isRequired)
                .map {
                    CandidateSelectionIssue(
                        member: $0,
                        title: "필참 불가",
                        symbolName: "xmark.circle.fill",
                        tint: Color(uiColor: .systemRed)
                    )
                }
        case .burden:
            return summary.burdenMembers.map {
                CandidateSelectionIssue(
                    member: $0,
                    title: $0.category.burdenTitle,
                    symbolName: $0.category.symbolName,
                    tint: Color(uiColor: .systemOrange)
                )
            }
        case .availability:
            let burdenIssues = summary.burdenMembers.map {
                CandidateSelectionIssue(
                    member: $0,
                    title: $0.category.burdenTitle,
                    symbolName: $0.category.symbolName,
                    tint: Color(uiColor: .systemOrange)
                )
            }
            let unavailableIssues = summary.unavailableMembers.map {
                CandidateSelectionIssue(
                    member: $0,
                    title: "불가",
                    symbolName: "xmark.circle.fill",
                    tint: Color(uiColor: .systemRed)
                )
            }
            return burdenIssues + unavailableIssues
        case .finalRanking:
            let burdenIssues = summary.burdenMembers.map {
                CandidateSelectionIssue(
                    member: $0,
                    title: $0.category.burdenTitle,
                    symbolName: $0.category.symbolName,
                    tint: Color(uiColor: .systemOrange)
                )
            }
            let unavailableIssues = summary.unavailableMembers.map {
                CandidateSelectionIssue(
                    member: $0,
                    title: "불가",
                    symbolName: "xmark.circle.fill",
                    tint: Color(uiColor: .systemRed)
                )
            }
            return burdenIssues + unavailableIssues
        case .criteria:
            return []
        }
    }
}

private struct CandidateSelectionDetailMessage: View {
    let text: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.1), in: Circle())

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private struct CandidateSelectionIssue: Identifiable {
    let member: TeamResponseReason
    let title: String
    let symbolName: String
    let tint: Color

    var id: String {
        "\(member.id)-\(title)"
    }
}

private struct CandidateSelectionIssueRow: View {
    let issue: CandidateSelectionIssue

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ProfileAvatar(
                name: issue.member.name,
                fallback: ProfileAsset.fallbackText(for: issue.member.name),
                size: 30,
                tint: issue.tint,
                borderColor: Color.clear,
                borderWidth: 0
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(issue.member.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: issue.symbolName)
                            .font(.system(size: 9, weight: .bold))

                        Text(issue.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(issue.tint)
                }

                Text(issue.member.displayReason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 64)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CandidateSelectionResponseCount: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)

            Text("\(title) \(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(tint.opacity(0.09), in: Capsule())
    }
}

private struct CandidateSelectionFinalRow: View {
    let candidate: FinalDerivationCandidate
    let calendar: Calendar

    private var tint: Color {
        candidate.rank == 0 ? Color(uiColor: .systemBlue) : Color(uiColor: .systemIndigo)
    }

    private var attendableCount: Int {
        candidate.summary.availableCount + candidate.summary.burdenCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(candidate.rank == 0 ? "추천" : "차순위")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(tint.opacity(0.1), in: Capsule())

                Spacer(minLength: 8)

                Text(candidate.slot.fullDateText(calendar: calendar))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(candidate.slot.timeRangeText)
                .font(.system(size: 21, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(candidate.rationale.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .semibold))

                Text("\(attendableCount)명 참석")

                Text("·")
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))

                Text(candidate.summary.burdenCount == 0 ? "부담 없음" : "부담 \(candidate.summary.burdenCount)명")
                    .foregroundStyle(
                        candidate.summary.burdenCount == 0
                            ? Color(uiColor: .systemGreen)
                            : Color(uiColor: .systemOrange)
                    )
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(candidate.rank == 0 ? 0.2 : 0.1), lineWidth: 0.8)
        }
    }
}

private struct SequentialDerivationTitle: View {
    let text: String
    let initialDelay: Double
    let characterInterval: Double
    let characterAnimationDuration: Double
    @State private var visibleCharacterCount = 0

    private var characters: [String] {
        text.map(String.init)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                let isVisible = index < visibleCharacterCount

                Text(character)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 4)
                    .blur(radius: isVisible ? 0 : 0.9)
                    .animation(
                        .interpolatingSpring(stiffness: 240, damping: 30, initialVelocity: 0),
                        value: isVisible
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(text)
        .transition(.opacity.combined(with: .offset(y: 3)))
        .task(id: text) {
            visibleCharacterCount = 0

            do {
                try await Task.sleep(for: .seconds(initialDelay))

                for index in characters.indices {
                    try Task.checkCancellation()

                    withAnimation(.easeInOut(duration: characterAnimationDuration)) {
                        visibleCharacterCount = index + 1
                    }

                    if index < characters.count - 1 {
                        try await Task.sleep(for: .seconds(characterInterval))
                    }
                }
            } catch {
                return
            }
        }
    }
}

private struct OnboardingResponseBlockStage: View {
    let slots: [DerivationResponseSlot]
    let revealsBlocks: Bool
    let revealInterval: Double
    let revealAnimationResponse: Double
    let criteria: DerivationCriteria
    let dimsCriteriaExcludedSlots: Bool
    let dimsUnavailableSlots: Bool
    let dimsBurdenHeavySlots: Bool
    let dimsLowAvailabilitySlots: Bool
    let dimsNonFinalSlots: Bool
    let hidesCriteriaExcludedSlots: Bool
    let hidesUnavailableSlots: Bool
    let hidesBurdenHeavySlots: Bool
    let hidesLowAvailabilitySlots: Bool
    let hidesNonFinalSlots: Bool
    let burdenExclusionThreshold: Int?
    let minimumPreferredAvailableCount: Int?
    let finalSlotIDs: Set<String>
    let calendar: Calendar

    private let columnCount = 5
    private let columnSpacing: CGFloat = 7
    private let rowSpacing: CGFloat = 7
    private let rowHeight: CGFloat = 58

    private var displayedSlots: [DerivationResponseSlot] {
        let filteredSlots = slots.filter { slot in
            if hidesCriteriaExcludedSlots && criteria.excludes(hour: slot.hour) {
                return false
            }

            if hidesUnavailableSlots && slot.requiredUnavailableCount > 0 {
                return false
            }

            if hidesBurdenHeavySlots && isBurdenExcluded(slot) {
                return false
            }

            if hidesLowAvailabilitySlots && isLowAvailabilityExcluded(slot) {
                return false
            }

            if hidesNonFinalSlots && !finalSlotIDs.contains(slot.id) {
                return false
            }

            return true
        }

        return DerivationResponseSlot.reindexedRows(for: filteredSlots)
    }

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = max(
                (proxy.size.width - CGFloat(columnCount - 1) * columnSpacing) / CGFloat(columnCount),
                0
            )

            ZStack(alignment: .topLeading) {
                ForEach(Array(displayedSlots.enumerated()), id: \.element.id) { index, slot in
                    OnboardingResponseBlockCard(
                        slot: slot,
                        width: columnWidth,
                        rowHeight: rowHeight,
                        isDimmed: isDimmed(slot)
                    )
                    .equatable()
                    .position(
                        x: CGFloat(slot.dayIndex) * (columnWidth + columnSpacing) + columnWidth / 2,
                        y: CGFloat(slot.rowIndex) * (rowHeight + rowSpacing) + rowHeight / 2
                    )
                    .opacity(revealsBlocks ? 1 : 0)
                    .scaleEffect(revealsBlocks ? 1 : 0.96)
                    .animation(
                        .spring(response: revealAnimationResponse, dampingFraction: 0.88)
                            .delay(
                                Double(index) * revealInterval
                                    + Double(index % columnCount) * 0.025
                                    + Double(index / columnCount) * 0.04
                            ),
                        value: revealsBlocks
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        )
                    )
                }
            }
            .frame(width: proxy.size.width, height: stageHeight, alignment: .topLeading)
        }
        .frame(height: stageHeight)
    }

    private var stageHeight: CGFloat {
        let rowCount = max((displayedSlots.map(\.rowIndex).max() ?? 0) + 1, 1)
        return CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * rowSpacing
    }

    private func isDimmed(_ slot: DerivationResponseSlot) -> Bool {
        if dimsCriteriaExcludedSlots && criteria.excludes(hour: slot.hour) {
            return true
        }

        if dimsUnavailableSlots && slot.requiredUnavailableCount > 0 {
            return true
        }

        if dimsBurdenHeavySlots && isBurdenExcluded(slot) {
            return true
        }

        if dimsLowAvailabilitySlots && isLowAvailabilityExcluded(slot) {
            return true
        }

        return dimsNonFinalSlots && !finalSlotIDs.contains(slot.id)
    }

    private func isBurdenExcluded(_ slot: DerivationResponseSlot) -> Bool {
        guard let burdenExclusionThreshold else {
            return false
        }

        return slot.requiredUnavailableCount == 0 && slot.weightedBurdenScore >= burdenExclusionThreshold
    }

    private func isLowAvailabilityExcluded(_ slot: DerivationResponseSlot) -> Bool {
        guard let minimumPreferredAvailableCount else {
            return false
        }

        return slot.requiredUnavailableCount == 0 && slot.availableCount < minimumPreferredAvailableCount
    }

}

private struct OnboardingResponseBlockCard: View, Equatable {
    let slot: DerivationResponseSlot
    let width: CGFloat
    let rowHeight: CGFloat
    let isDimmed: Bool

    private var hasRequiredUnavailable: Bool {
        slot.requiredUnavailableCount > 0
    }

    private var hasOptionalUnavailable: Bool {
        slot.optionalUnavailableCount > 0
    }

    private var hasBurden: Bool {
        slot.burdenCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(slot.compactDayText(calendar: slot.calendar))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                if hasRequiredUnavailable && !isDimmed {
                    Circle()
                        .fill(Color(uiColor: .systemRed).opacity(0.82))
                        .frame(width: 5, height: 5)
                } else if hasOptionalUnavailable && !isDimmed {
                    Circle()
                        .fill(Color(uiColor: .systemOrange).opacity(0.76))
                        .frame(width: 5, height: 5)
                }
            }

            Text(slot.timeText)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 3) {
                OnboardingCompactCount(label: "가", count: slot.availableCount, color: Color(uiColor: .systemGreen))
                OnboardingCompactCount(label: "부", count: slot.burdenCount, color: Color(uiColor: .systemOrange))
                OnboardingCompactCount(label: "불", count: slot.unavailableCount, color: Color(uiColor: .systemRed))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(width: width, height: rowHeight, alignment: .topLeading)
        .background(
            blockBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    strokeColor,
                    lineWidth: strokeLineWidth
                )
        }
        .opacity(isDimmed ? 0.46 : 1)
        .scaleEffect(isDimmed ? 0.96 : 1)
    }

    private var blockBackground: Color {
        if isDimmed {
            if hasRequiredUnavailable {
                return Color(uiColor: .systemRed).opacity(0.12)
            }

            if hasOptionalUnavailable || hasBurden {
                return Color(uiColor: .systemOrange).opacity(0.11)
            }

            return Color(uiColor: .systemBackground).opacity(0.82)
        }

        if hasRequiredUnavailable {
            return Color(uiColor: .systemRed).opacity(0.075)
        }

        if hasOptionalUnavailable {
            return Color(uiColor: .systemOrange).opacity(0.07)
        }

        return Color(uiColor: .secondarySystemBackground).opacity(0.94)
    }

    private var strokeColor: Color {
        if isDimmed {
            if hasRequiredUnavailable {
                return Color(uiColor: .systemRed).opacity(0.2)
            }

            if hasOptionalUnavailable || hasBurden {
                return Color(uiColor: .systemOrange).opacity(0.18)
            }

            return Color.white.opacity(0.7)
        }

        if hasRequiredUnavailable {
            return Color(uiColor: .systemRed).opacity(0.22)
        }

        if hasOptionalUnavailable {
            return Color(uiColor: .systemOrange).opacity(0.18)
        }

        return Color(uiColor: .separator).opacity(0.08)
    }

    private var strokeLineWidth: CGFloat {
        if isDimmed {
            return 0.8
        }

        return (hasRequiredUnavailable || hasOptionalUnavailable) ? 0.9 : 0.7
    }
}

private struct DerivationResponseSlot: Identifiable, Hashable {
    let date: Date
    let dayIndex: Int
    let rowIndex: Int
    let hour: Int
    let availableCount: Int
    let burdenCount: Int
    let weightedBurdenScore: Int
    let unavailableCount: Int
    let requiredAvailableCount: Int
    let requiredUnavailableCount: Int
    let optionalAvailableCount: Int
    let optionalUnavailableCount: Int
    let requiredTotalCount: Int
    let optionalTotalCount: Int
    let calendar: Calendar

    var id: String {
        "\(dayIndex)-\(hour)-\(availableCount)-\(burdenCount)-\(weightedBurdenScore)-\(unavailableCount)-\(requiredUnavailableCount)-\(optionalUnavailableCount)"
    }

    var mergeSignature: String {
        "\(availableCount)-\(burdenCount)-\(unavailableCount)"
    }

    var timeText: String {
        "\(String(format: "%02d", hour)):00"
    }

    var timeRangeText: String {
        "\(String(format: "%02d", hour)):00 - \(String(format: "%02d", hour + 1)):00"
    }

    func compactDayText(calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(min(calendar.component(.weekday, from: date) - 1, symbols.count - 1), 0)
        return "\(symbols[index]) \(day)"
    }

    func collapsedDateText(calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let symbols = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
        let index = max(min(calendar.component(.weekday, from: date) - 1, symbols.count - 1), 0)
        return "\(day)일 \(symbols[index])"
    }

    func fullDateText(calendar: Calendar) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(min(calendar.component(.weekday, from: date) - 1, symbols.count - 1), 0)
        return "\(month)월 \(day)일 \(symbols[index])요일"
    }

    static func makeSlots(for meeting: HomeMeeting, calendar: Calendar) -> [DerivationResponseSlot] {
        let dates = Array(candidateDates(from: meeting.candidateStartDate, to: meeting.candidateEndDate, calendar: calendar).prefix(5))
        let summaries = TeamResponseSummary.makeSummaries(for: meeting, dates: dates, calendar: calendar)
        let visibleHours = (9..<18).filter { hour in
            dates.contains { date in
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                return summaries[slot] != nil
            }
        }

        return visibleHours.enumerated().flatMap { rowIndex, hour in
            dates.enumerated().compactMap { dayIndex, date in
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                guard let summary = summaries[slot] else {
                    return nil
                }

                return DerivationResponseSlot(
                    date: calendar.startOfDay(for: date),
                    dayIndex: dayIndex,
                    rowIndex: rowIndex,
                    hour: hour,
                    availableCount: summary.availableCount,
                    burdenCount: summary.burdenCount,
                    weightedBurdenScore: summary.weightedBurdenScore,
                    unavailableCount: summary.unavailableCount,
                    requiredAvailableCount: summary.requiredAvailableCount,
                    requiredUnavailableCount: summary.requiredUnavailableCount,
                    optionalAvailableCount: summary.optionalAvailableCount,
                    optionalUnavailableCount: summary.optionalUnavailableCount,
                    requiredTotalCount: summary.requiredTotalCount,
                    optionalTotalCount: summary.optionalTotalCount,
                    calendar: calendar,
                )
            }
        }
    }

    static func reindexedRows(for slots: [DerivationResponseSlot]) -> [DerivationResponseSlot] {
        let sortedHours = Array(Set(slots.map(\.hour))).sorted()
        let rowIndexByHour = Dictionary(uniqueKeysWithValues: sortedHours.enumerated().map { index, hour in
            (hour, index)
        })

        return slots.map { slot in
            DerivationResponseSlot(
                date: slot.date,
                dayIndex: slot.dayIndex,
                rowIndex: rowIndexByHour[slot.hour] ?? slot.rowIndex,
                hour: slot.hour,
                availableCount: slot.availableCount,
                burdenCount: slot.burdenCount,
                weightedBurdenScore: slot.weightedBurdenScore,
                unavailableCount: slot.unavailableCount,
                requiredAvailableCount: slot.requiredAvailableCount,
                requiredUnavailableCount: slot.requiredUnavailableCount,
                optionalAvailableCount: slot.optionalAvailableCount,
                optionalUnavailableCount: slot.optionalUnavailableCount,
                requiredTotalCount: slot.requiredTotalCount,
                optionalTotalCount: slot.optionalTotalCount,
                calendar: slot.calendar
            )
        }
    }

    private static func candidateDates(from startDate: Date, to endDate: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        guard start <= end else {
            return [start]
        }

        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = nextDate
        }

        return dates
    }
}

private struct DerivationResponseBlock: Identifiable, Hashable {
    let date: Date
    let dayIndex: Int
    let startHour: Int
    let endHour: Int
    let availableCount: Int
    let burdenCount: Int
    let unavailableCount: Int
    let calendar: Calendar

    var id: String {
        "\(dayIndex)-\(startHour)-\(endHour)-\(availableCount)-\(burdenCount)-\(unavailableCount)"
    }

    var hourSpan: Int {
        max(endHour - startHour, 1)
    }

    var timeRangeText: String {
        if hourSpan == 1 {
            return "\(String(format: "%02d", startHour)):00"
        }

        return "\(String(format: "%02d", startHour)):00-\(String(format: "%02d", endHour)):00"
    }

    init(slot: DerivationResponseSlot) {
        self.date = slot.date
        self.dayIndex = slot.dayIndex
        self.startHour = slot.hour
        self.endHour = slot.hour + 1
        self.availableCount = slot.availableCount
        self.burdenCount = slot.burdenCount
        self.unavailableCount = slot.unavailableCount
        self.calendar = slot.calendar
    }

    init(
        date: Date,
        dayIndex: Int,
        startHour: Int,
        endHour: Int,
        availableCount: Int,
        burdenCount: Int,
        unavailableCount: Int,
        calendar: Calendar
    ) {
        self.date = date
        self.dayIndex = dayIndex
        self.startHour = startHour
        self.endHour = endHour
        self.availableCount = availableCount
        self.burdenCount = burdenCount
        self.unavailableCount = unavailableCount
        self.calendar = calendar
    }

    func compactDayText(calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(min(calendar.component(.weekday, from: date) - 1, symbols.count - 1), 0)
        return "\(symbols[index]) \(day)"
    }

    static func mergedBlocks(from slots: [DerivationResponseSlot]) -> [DerivationResponseBlock] {
        Dictionary(grouping: slots, by: \.dayIndex)
            .flatMap { _, daySlots -> [DerivationResponseBlock] in
                let sortedSlots = daySlots.sorted { $0.hour < $1.hour }
                var blocks: [DerivationResponseBlock] = []
                var currentSlots: [DerivationResponseSlot] = []

                for slot in sortedSlots {
                    if let previous = currentSlots.last,
                       previous.hour + 1 == slot.hour,
                       previous.mergeSignature == slot.mergeSignature {
                        currentSlots.append(slot)
                    } else {
                        if let block = makeBlock(from: currentSlots) {
                            blocks.append(block)
                        }

                        currentSlots = [slot]
                    }
                }

                if let block = makeBlock(from: currentSlots) {
                    blocks.append(block)
                }

                return blocks
            }
            .sorted {
                if $0.startHour == $1.startHour {
                    return $0.dayIndex < $1.dayIndex
                }

                return $0.startHour < $1.startHour
            }
    }

    static func isBetterCandidate(_ lhs: DerivationResponseBlock, _ rhs: DerivationResponseBlock) -> Bool {
        let lhsScore = lhs.availableCount * 10 + lhs.hourSpan * 4 - lhs.burdenCount * 3 - abs(lhs.startHour - 14)
        let rhsScore = rhs.availableCount * 10 + rhs.hourSpan * 4 - rhs.burdenCount * 3 - abs(rhs.startHour - 14)

        if lhsScore == rhsScore {
            if lhs.burdenCount == rhs.burdenCount {
                return lhs.startHour < rhs.startHour
            }

            return lhs.burdenCount < rhs.burdenCount
        }

        return lhsScore > rhsScore
    }

    private static func makeBlock(from slots: [DerivationResponseSlot]) -> DerivationResponseBlock? {
        guard let first = slots.first, let last = slots.last else {
            return nil
        }

        return DerivationResponseBlock(
            date: first.date,
            dayIndex: first.dayIndex,
            startHour: first.hour,
            endHour: last.hour + 1,
            availableCount: first.availableCount,
            burdenCount: first.burdenCount,
            unavailableCount: first.unavailableCount,
            calendar: first.calendar
        )
    }
}

private struct OnboardingCompactCount: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(count > 0 ? color : Color(uiColor: .tertiaryLabel))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct ResponseCountPill: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(count > 0 ? color : Color(uiColor: .tertiaryLabel))
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background((count > 0 ? color.opacity(0.1) : Color(uiColor: .systemFill).opacity(0.45)), in: Capsule())
    }
}

private struct DerivationStatusHeader: View {
    let phase: MeetingDerivationPhase
    let candidateCount: Int
    let finalCount: Int

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemBlue).opacity(0.12))

                Image(systemName: phase == .final ? "checkmark" : "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(phase.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .contentTransition(.opacity)

                Text(phase.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer()

            Text(phase == .final ? "\(finalCount)안" : "\(candidateCount)개")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color(uiColor: .systemBlue))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(uiColor: .systemBlue).opacity(0.1), in: Capsule())
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct DerivationCalendarGhost: View {
    let candidates: [MeetingDecisionCandidate]
    let calendar: Calendar
    let phase: MeetingDerivationPhase

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("응답 시간표")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("6/6")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color(uiColor: .systemFill).opacity(0.55), in: Capsule())
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(candidates.prefix(10).enumerated()), id: \.element.id) { index, candidate in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill).opacity(candidate.unavailableCount > 0 ? 0.46 : 0.58))
                        .overlay(alignment: .topTrailing) {
                            if candidate.unavailableCount > 0 {
                                Circle()
                                    .fill(Color(uiColor: .systemRed).opacity(0.82))
                                    .frame(width: 4.5, height: 4.5)
                                    .padding(5)
                            }
                        }
                        .frame(height: 32)
                        .opacity(phase == .preparing ? 1 : 0.18)
                        .scaleEffect(phase == .preparing ? 1 : 0.96)
                        .offset(y: phase == .preparing ? 0 : -10)
                        .animation(.spring(response: 0.58, dampingFraction: 0.9).delay(Double(index) * 0.035), value: phase)
                }
            }

            Capsule()
                .fill(Color.primary.opacity(0.82))
                .frame(width: 44, height: 4)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(phase == .preparing ? 1 : 0.28)
        .scaleEffect(phase == .preparing ? 1 : 0.92, anchor: .top)
        .offset(y: phase == .preparing ? 0 : -26)
    }
}

private struct DerivationCandidateStage: View {
    let phase: MeetingDerivationPhase
    let candidates: [MeetingDecisionCandidate]
    let finalCandidates: [MeetingDecisionCandidate]
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        Group {
            if phase == .final {
                HStack(spacing: 10) {
                    ForEach(Array(finalCandidates.enumerated()), id: \.element.id) { index, candidate in
                        DerivationFinalCandidateCard(
                            index: index,
                            candidate: candidate,
                            calendar: calendar
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                        DerivationCandidateCard(
                            candidate: candidate,
                            calendar: calendar,
                            isFinalist: finalCandidates.contains(candidate),
                            phase: phase
                        )
                        .animation(.spring(response: 0.62, dampingFraction: 0.88).delay(Double(index) * 0.045), value: phase)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

private struct DerivationCandidateCard: View {
    let candidate: MeetingDecisionCandidate
    let calendar: Calendar
    let isFinalist: Bool
    let phase: MeetingDerivationPhase

    private var isFilteredOut: Bool {
        candidate.unavailableCount > 0
    }

    private var isComparingOut: Bool {
        phase == .comparing && !isFinalist
    }

    private var cardOpacity: Double {
        if phase == .filtering, isFilteredOut {
            return 0.18
        }

        if isComparingOut {
            return 0.16
        }

        return 1
    }

    private var cardScale: CGFloat {
        if phase == .filtering, isFilteredOut {
            return 0.92
        }

        if isComparingOut {
            return 0.9
        }

        return 1
    }

    private var yOffset: CGFloat {
        if phase == .filtering, isFilteredOut {
            return 18
        }

        if isComparingOut {
            return 26
        }

        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(candidate.dayText(calendar: calendar))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Circle()
                    .fill(candidate.statusColor)
                    .frame(width: 6, height: 6)
            }

            Text(candidate.timeText)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)

            HStack(spacing: 5) {
                Text(isFinalist ? "검토 유지" : candidate.reasonText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isFinalist ? Color(uiColor: .systemBlue) : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(isFinalist && phase == .comparing ? Color(uiColor: .systemBlue).opacity(0.35) : Color.clear, lineWidth: 1)
        }
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .offset(y: yOffset)
    }
}

private struct DerivationFinalCandidateCard: View {
    let index: Int
    let candidate: MeetingDecisionCandidate
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(index == 0 ? "추천안" : "대안")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(index == 0 ? Color(uiColor: .systemBlue) : .secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(
                        (index == 0 ? Color(uiColor: .systemBlue).opacity(0.1) : Color(uiColor: .systemFill).opacity(0.62)),
                        in: Capsule()
                    )

                Spacer()

                Label("선정 근거", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(index == 0 ? Color(uiColor: .systemBlue) : .secondary)
                    .labelStyle(.iconOnly)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.dayText(calendar: calendar))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(candidate.timeText)
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                MeetingDecisionMetric(text: "\(candidate.requiredAvailable)/\(candidate.requiredTotal) 필참", color: Color(uiColor: .systemGreen))
                MeetingDecisionMetric(text: "\(candidate.optionalAvailable)/\(candidate.optionalTotal) 선택", color: Color(uiColor: .systemBlue))
                MeetingDecisionMetric(text: candidate.reasonText, color: candidate.statusColor)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(index == 0 ? Color(uiColor: .systemBlue).opacity(0.28) : Color.clear, lineWidth: 1)
        }
    }
}

private struct DecisionOverviewCard: View {
    let candidateCount: Int
    let finalCount: Int
    let memberCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBlue))
                .frame(width: 42, height: 42)
                .background(Color(uiColor: .systemBlue).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("필참 조건을 먼저 통과한 후보")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(candidateCount)개 검토 후보를 비교해 추천 \(finalCount)안을 남겼어요")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(memberCount)/\(memberCount)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color(uiColor: .systemBlue))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(uiColor: .systemBlue).opacity(0.1), in: Capsule())
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct DailyCandidateExtractionCard: View {
    let candidates: [MeetingDecisionCandidate]
    let calendar: Calendar

    private var dayBuckets: [MeetingDecisionDayBucket] {
        let grouped = Dictionary(grouping: candidates) { candidate in
            calendar.startOfDay(for: candidate.date)
        }

        return grouped.keys.sorted().map { date in
            MeetingDecisionDayBucket(date: date, candidates: grouped[date, default: []].sorted { $0.score > $1.score })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("요일별 검토 후보")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("최대 2개씩")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(Color(uiColor: .systemBackground), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dayBuckets) { bucket in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(dayTitle(for: bucket.date))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            ForEach(bucket.candidates) { candidate in
                                DailyCandidatePill(candidate: candidate)
                            }
                        }
                        .padding(10)
                        .frame(width: 118, alignment: .topLeading)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }

    private func dayTitle(for date: Date) -> String {
        let day = calendar.component(.day, from: date)
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekday = weekdaySymbols[max(calendar.component(.weekday, from: date) - 1, 0)]
        return "\(day)일 \(weekday)"
    }
}

private struct DailyCandidatePill: View {
    let candidate: MeetingDecisionCandidate

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(candidate.statusColor)
                .frame(width: 5, height: 5)

            Text(candidate.timeText)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(candidate.reasonText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }
}

private struct DecisionTournamentCard: View {
    let candidates: [MeetingDecisionCandidate]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("비교 과정")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    HStack(spacing: 10) {
                        Text(index < 2 ? "유지" : "소거")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(index < 2 ? Color(uiColor: .systemBlue) : Color(uiColor: .tertiaryLabel))
                            .frame(width: 34, height: 24)
                            .background(
                                (index < 2 ? Color(uiColor: .systemBlue).opacity(0.1) : Color(uiColor: .systemFill).opacity(0.58)),
                                in: Capsule()
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.fullDateText(calendar: calendar))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(candidate.reasonText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(index < 2 ? "선정" : "제외")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(index < 2 ? Color(uiColor: .systemBlue) : .secondary)
                    }
                    .padding(10)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct FinalMeetingProposalCard: View {
    let candidates: [MeetingDecisionCandidate]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("최종 2안")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("주최자 확정")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(index == 0 ? "추천" : "대안")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(index == 0 ? Color(uiColor: .systemBlue) : .secondary)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(
                                    (index == 0 ? Color(uiColor: .systemBlue).opacity(0.1) : Color(uiColor: .systemFill).opacity(0.62)),
                                    in: Capsule()
                                )

                            Spacer()

                            Label("선정 근거", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(index == 0 ? Color(uiColor: .systemBlue) : .secondary)
                                .labelStyle(.iconOnly)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.dayText(calendar: calendar))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(candidate.timeText)
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            MeetingDecisionMetric(text: "\(candidate.requiredAvailable)/\(candidate.requiredTotal) 필참", color: Color(uiColor: .systemGreen))
                            MeetingDecisionMetric(text: "\(candidate.optionalAvailable)/\(candidate.optionalTotal) 선택", color: Color(uiColor: .systemBlue))
                            MeetingDecisionMetric(text: candidate.reasonText, color: candidate.statusColor)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Button {
                print("Confirm recommended candidate")
            } label: {
                Text("추천안으로 확정하기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(uiColor: .systemBlue), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(HomeGridMetrics.cardPadding)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct MeetingDecisionMetric: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct MeetingDecisionDayBucket: Identifiable {
    let date: Date
    let candidates: [MeetingDecisionCandidate]

    var id: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }
}

private struct MeetingDecisionCandidate: Identifiable, Hashable {
    let date: Date
    let hour: Int
    let score: Int
    let requiredAvailable: Int
    let requiredTotal: Int
    let optionalAvailable: Int
    let optionalTotal: Int
    let burdenCount: Int
    let unavailableCount: Int

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(hour)-\(score)-\(burdenCount)-\(unavailableCount)"
    }

    var timeText: String {
        "\(String(format: "%02d", hour)):00"
    }

    var reasonText: String {
        if unavailableCount > 0 {
            return "선택 \(unavailableCount)명 불가"
        }

        if burdenCount > 0 {
            return "부담 \(burdenCount)명"
        }

        return "충돌 없음"
    }

    var statusColor: Color {
        if unavailableCount > 0 {
            return Color(uiColor: .systemRed)
        }

        if burdenCount > 0 {
            return Color(uiColor: .systemOrange)
        }

        return Color(uiColor: .systemGreen)
    }

    func dayText(calendar: Calendar) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = weekdayText(calendar: calendar)
        return "\(month)월 \(day)일 \(weekday)"
    }

    func compactDayText(calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let weekday = weekdayText(calendar: calendar)
        return "\(weekday) \(day)"
    }

    func fullDateText(calendar: Calendar) -> String {
        "\(dayText(calendar: calendar)) \(timeText)"
    }

    private func weekdayText(calendar: Calendar) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(min(calendar.component(.weekday, from: date) - 1, symbols.count - 1), 0)
        return symbols[index]
    }

    static func makeCandidates(for meeting: HomeMeeting, calendar: Calendar) -> [MeetingDecisionCandidate] {
        let dates = candidateDates(from: meeting.candidateStartDate, to: meeting.candidateEndDate, calendar: calendar)
        let summaries = TeamResponseSummary.makeSummaries(for: meeting, dates: dates, calendar: calendar)

        return dates.enumerated().flatMap { dayIndex, date in
            let dailyCandidates = (9..<18).compactMap { hour -> MeetingDecisionCandidate? in
                guard !meeting.excludedTimeRule.excludes(hour: hour, date: date, calendar: calendar) else {
                    return nil
                }

                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                guard let summary = summaries[slot], summary.requiredUnavailableCount == 0 else {
                    return nil
                }

                let timePreferencePenalty = meeting.derivationCriteria.timePreferencePenalty(for: hour)
                let score = max(
                    56,
                    100 - summary.optionalUnavailableCount * 11 - summary.weightedBurdenScore * 5 - timePreferencePenalty - dayIndex
                )

                return MeetingDecisionCandidate(
                    date: calendar.startOfDay(for: date),
                    hour: hour,
                    score: score,
                    requiredAvailable: summary.requiredAvailableCount,
                    requiredTotal: summary.requiredTotalCount,
                    optionalAvailable: summary.optionalAvailableCount,
                    optionalTotal: summary.optionalTotalCount,
                    burdenCount: summary.burdenCount,
                    unavailableCount: summary.optionalUnavailableCount
                )
            }

            return Array(dailyCandidates.sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.hour < rhs.hour
                }

                return lhs.score > rhs.score
            }.prefix(2))
        }
    }

    static func makeOnboardingGridCandidates(for meeting: HomeMeeting, calendar: Calendar) -> [MeetingDecisionCandidate] {
        let dates = Array(candidateDates(from: meeting.candidateStartDate, to: meeting.candidateEndDate, calendar: calendar).prefix(5))
        let summaries = TeamResponseSummary.makeSummaries(for: meeting, dates: dates, calendar: calendar)

        return (9..<18).flatMap { hour in
            dates.enumerated().compactMap { dayIndex, date in
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                guard let summary = summaries[slot] else {
                    return nil
                }

                let timePreferencePenalty = meeting.derivationCriteria.timePreferencePenalty(for: hour)
                let score = max(
                    56,
                    100 - summary.optionalUnavailableCount * 11 - summary.weightedBurdenScore * 5 - timePreferencePenalty - dayIndex
                )

                return MeetingDecisionCandidate(
                    date: calendar.startOfDay(for: date),
                    hour: hour,
                    score: score,
                    requiredAvailable: summary.requiredAvailableCount,
                    requiredTotal: summary.requiredTotalCount,
                    optionalAvailable: summary.optionalAvailableCount,
                    optionalTotal: summary.optionalTotalCount,
                    burdenCount: summary.burdenCount,
                    unavailableCount: summary.optionalUnavailableCount
                )
            }
        }
    }

    private static func candidateDates(from startDate: Date, to endDate: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        guard start <= end else {
            return [start]
        }

        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = nextDate
        }

        return dates
    }
}

private struct ConfirmedDayScheduleView: View {
    let selectedDate: Date?
    let meeting: HomeMeeting
    let rowHeight: CGFloat
    let bottomContentInset: CGFloat
    let calendar: Calendar

    private let hours = Array(9..<18)
    private let workStartHour = 9
    private let workEndHour = 18

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - LayoutMetrics.horizontalPadding * 2, 0)
            let timelineWidth = max(
                contentWidth - LayoutMetrics.timeAxisWidth - LayoutMetrics.scheduleColumnSpacing,
                0
            )

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: LayoutMetrics.scheduleColumnSpacing) {
                    timeAxis
                        .frame(width: LayoutMetrics.timeAxisWidth)

                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            gridBackground(width: timelineWidth)

                            if isMeetingDate {
                                confirmedMeetingBlock(width: timelineWidth)
                            }
                        }
                        .frame(width: timelineWidth, height: gridHeight)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.bottom, bottomContentInset)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var timeAxis: some View {
        VStack(spacing: 3) {
            ForEach(hours, id: \.self) { hour in
                Text("\(hour)시")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: LayoutMetrics.timeAxisWidth, height: rowHeight - 3, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(width: LayoutMetrics.timeAxisWidth, height: gridHeight, alignment: .topTrailing)
    }

    private func gridBackground(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(workStartHour..<workEndHour, id: \.self) { hour in
                let cellHeight = rowHeight - 3

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(uiColor: .systemGray6).opacity(0.72))
                    .frame(width: width, height: cellHeight)
                    .position(
                        x: width / 2,
                        y: yCenter(for: hour, height: cellHeight)
                    )
            }
        }
        .frame(width: width, height: gridHeight, alignment: .topLeading)
    }

    private func confirmedMeetingBlock(width: CGFloat) -> some View {
        let height = rowHeight - 3
        let tint = meeting.iconTint

        return HStack(spacing: 12) {
            Image(systemName: meeting.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(meeting.timeRange) · \(meetingPlaceText)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            AvatarStack(
                names: meeting.memberInitials,
                maxVisible: 3,
                size: 24,
                borderColor: Color(uiColor: .systemBackground),
                borderWidth: 1.8,
                overlap: 8
            )

            Text("\(meeting.memberCount)명")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: height)
        .background(
            tint.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 0.8)
        }
        .position(
            x: width / 2,
            y: yCenter(for: confirmedStartHour, height: height)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meeting.title), \(meeting.timeRange), 참석자 \(meeting.memberCount)명")
    }

    private var displayedDate: Date {
        selectedDate ?? meeting.focusDate
    }

    private var isMeetingDate: Bool {
        calendar.isDate(displayedDate, inSameDayAs: meeting.focusDate)
    }

    private var confirmedStartHour: Int {
        let firstComponent = meeting.timeRange
            .components(separatedBy: "-")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ":")
            .first

        return min(max(Int(firstComponent ?? "") ?? workStartHour, workStartHour), workEndHour - 1)
    }

    private var meetingPlaceText: String {
        let components = meeting.subtitle
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let modeIndex = components.firstIndex(where: { $0 == "온라인" || $0 == "오프라인" }) else {
            return meeting.sectionName
        }

        let locationIndex = components.index(after: modeIndex)
        return locationIndex < components.endIndex ? components[locationIndex] : components[modeIndex]
    }

    private var gridHeight: CGFloat {
        CGFloat(hours.count) * rowHeight
    }

    private func yCenter(for hour: Int, height: CGFloat) -> CGFloat {
        CGFloat(hour - workStartHour) * rowHeight + height / 2
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

private struct CustomExcludedTimeSheet: View {
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

private struct MeetingDraft {
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

private struct ExcludedTimeRule: Equatable {
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

private enum ExcludedTimePreset: String, CaseIterable, Identifiable {
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
                    AvatarStack(names: meeting.memberInitials, maxVisible: 3)

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
                AvatarStack(names: meeting.memberInitials, maxVisible: 3)

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
    var maxVisible: Int = 5
    var size: CGFloat = 28
    var borderColor: Color = Color(uiColor: .secondarySystemBackground)
    var borderWidth: CGFloat = 2
    var overlap: CGFloat = 8

    private var visibleNames: [String] {
        Array(names.prefix(max(maxVisible, 0)))
    }

    private var overflowCount: Int {
        max(names.count - visibleNames.count, 0)
    }

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(visibleNames.enumerated()), id: \.offset) { index, name in
                ProfileAvatar(
                    name: name,
                    fallback: ProfileAsset.fallbackText(for: name),
                    size: size,
                    tint: Self.colors[index % Self.colors.count],
                    borderColor: borderColor,
                    borderWidth: borderWidth
                )
                .zIndex(Double(index))
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color(uiColor: .systemGray5), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(borderColor, lineWidth: borderWidth)
                    }
                    .zIndex(Double(visibleNames.count))
            }
        }
        .frame(height: size)
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
    let iconName: String
    let subtitle: String
    let dateRange: String
    let timeRange: String
    let excludedTimeRule: ExcludedTimeRule
    let derivationCriteria: DerivationCriteria
    let hostAvailabilityEntries: [AvailabilitySlot: AvailabilityEntry]
    let memberCount: Int
    let respondedCount: Int
    let status: MeetingStatus
    let stage: MeetingStage
    let memberInitials: [String]
    let requiredMemberIndexes: Set<Int>
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

    var iconTint: Color {
        MeetingIconStyle.tint(for: iconName)
    }

    func sharedWithMembers(hostAvailabilityEntries: [AvailabilitySlot: AvailabilityEntry]) -> HomeMeeting {
        let normalizedMembers = Self.prototypeSixMembers(from: memberInitials)
        let normalizedRequiredIndexes = Self.normalizedRequiredIndexes(
            from: requiredMemberIndexes,
            memberCount: normalizedMembers.count
        )

        return HomeMeeting(
            id: id,
            title: title,
            sectionName: sectionName,
            iconName: iconName,
            subtitle: subtitle,
            dateRange: dateRange,
            timeRange: timeRange,
            excludedTimeRule: excludedTimeRule,
            derivationCriteria: derivationCriteria,
            hostAvailabilityEntries: hostAvailabilityEntries,
            memberCount: normalizedMembers.count,
            respondedCount: normalizedMembers.count,
            status: .collecting,
            stage: .collectingResponses,
            memberInitials: normalizedMembers,
            requiredMemberIndexes: normalizedRequiredIndexes,
            focusDate: focusDate,
            candidateStartDate: candidateStartDate,
            candidateEndDate: candidateEndDate,
            confirmedDay: confirmedDay,
            confirmedWeekday: confirmedWeekday
        )
    }

    func readyForComparison(criteria: DerivationCriteria) -> HomeMeeting {
        HomeMeeting(
            id: id,
            title: title,
            sectionName: sectionName,
            iconName: iconName,
            subtitle: subtitle,
            dateRange: dateRange,
            timeRange: timeRange,
            excludedTimeRule: excludedTimeRule,
            derivationCriteria: criteria,
            hostAvailabilityEntries: hostAvailabilityEntries,
            memberCount: memberCount,
            respondedCount: memberCount,
            status: .ready,
            stage: .bracketReview,
            memberInitials: memberInitials,
            requiredMemberIndexes: normalizedRequiredIndexes,
            focusDate: focusDate,
            candidateStartDate: candidateStartDate,
            candidateEndDate: candidateEndDate,
            confirmedDay: confirmedDay,
            confirmedWeekday: confirmedWeekday
        )
    }

    func confirmed(on date: Date, hour: Int, calendar: Calendar) -> HomeMeeting {
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayIndex = max(calendar.component(.weekday, from: date) - 1, 0)
        let weekday = weekdaySymbols[min(weekdayIndex, weekdaySymbols.count - 1)]
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let confirmedTimeRange = String(format: "%02d:00 - %02d:00", hour, hour + 1)

        return HomeMeeting(
            id: id,
            title: title,
            sectionName: sectionName,
            iconName: iconName,
            subtitle: subtitle,
            dateRange: "\(month)월 \(day)일",
            timeRange: confirmedTimeRange,
            excludedTimeRule: excludedTimeRule,
            derivationCriteria: derivationCriteria,
            hostAvailabilityEntries: hostAvailabilityEntries,
            memberCount: memberCount,
            respondedCount: memberCount,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: memberInitials,
            requiredMemberIndexes: normalizedRequiredIndexes,
            focusDate: date,
            candidateStartDate: candidateStartDate,
            candidateEndDate: candidateEndDate,
            confirmedDay: "\(day)",
            confirmedWeekday: weekday
        )
    }

    var normalizedRequiredIndexes: Set<Int> {
        Self.normalizedRequiredIndexes(from: requiredMemberIndexes, memberCount: memberCount)
    }

    var requiredMemberCount: Int {
        normalizedRequiredIndexes.count
    }

    var optionalMemberCount: Int {
        max(memberCount - requiredMemberCount, 0)
    }

    func isRequiredMember(at index: Int) -> Bool {
        normalizedRequiredIndexes.contains(index)
    }

    static let sampleData = [
        HomeMeeting(
            id: "design-team-weekly",
            title: "디자인팀 회의",
            sectionName: "디자인팀",
            iconName: "paintpalette.fill",
            subtitle: "제품 방향성, IA, 화면 우선순위",
            dateRange: "7월 15일 - 18일",
            timeRange: "10:00 - 17:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 5,
            respondedCount: 3,
            status: .collecting,
            stage: .hostAvailability,
            memberInitials: ["나", "김민준", "이서연", "오유진", "송승아"],
            requiredMemberIndexes: [0, 1, 2, 3],
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
            iconName: "checklist",
            subtitle: "MVP 범위 점검",
            dateRange: "7월 16일 - 17일",
            timeRange: "14:00 - 16:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 4,
            respondedCount: 4,
            status: .ready,
            stage: .bracketReview,
            memberInitials: ["나", "문준호", "오유진", "정지우"],
            requiredMemberIndexes: [0, 1, 2],
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
            iconName: "bubble.left.and.bubble.right.fill",
            subtitle: "인터뷰 결과 공유",
            dateRange: "7월 21일 - 22일",
            timeRange: "09:00 - 12:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 6,
            respondedCount: 2,
            status: .waiting,
            stage: .collectingResponses,
            memberInitials: ["나", "정지우", "임다혜", "장혜진", "윤재현", "최하린"],
            requiredMemberIndexes: [0, 1, 2, 3],
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
            iconName: "sparkles",
            subtitle: "가이드라인 확정",
            dateRange: "7월 14일",
            timeRange: "11:00 - 12:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 3,
            respondedCount: 3,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: ["나", "한유나", "강태호"],
            requiredMemberIndexes: [0, 1, 2],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 14),
            confirmedDay: "14",
            confirmedWeekday: "화"
        )
    ]

    private static func prototypeSixMembers(from names: [String]) -> [String] {
        let fallbackNames = ["나", "김민준", "이서연", "오유진", "송승아", "박도윤"]
        var normalizedNames = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !normalizedNames.contains("나") {
            normalizedNames.insert("나", at: 0)
        }

        for name in fallbackNames where normalizedNames.count < 6 && !normalizedNames.contains(name) {
            normalizedNames.append(name)
        }

        return Array(normalizedNames.prefix(6))
    }

    private static func normalizedRequiredIndexes(from indexes: Set<Int>, memberCount: Int) -> Set<Int> {
        let validIndexes = indexes.filter { (0..<memberCount).contains($0) }
        guard !validIndexes.isEmpty else {
            let defaultRequiredCount = min(max(memberCount - 2, 1), 4)
            return Set(0..<defaultRequiredCount)
        }

        return validIndexes.union([0])
    }

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
    let showsDateRange: Bool
    let eventDates: [Date]
    let eventTint: Color
    let expansionProgress: CGFloat
    let calendar: Calendar

    var body: some View {
        ZStack(alignment: .top) {
            MonthCalendarView(
                month: month,
                selectedDate: $selectedDate,
                rangeStartDate: rangeStartDate,
                rangeEndDate: rangeEndDate,
                showsDateRange: showsDateRange,
                eventDates: eventDates,
                eventTint: eventTint,
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
                showsDateRange: showsDateRange,
                eventDates: eventDates,
                eventTint: eventTint,
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
    let showsDateRange: Bool
    let eventDates: [Date]
    let eventTint: Color
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
                            hasEvent: hasEvent(on: day.date),
                            eventTint: eventTint,
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
        showsDateRange && calendar.isDate(date, inSameDayAs: normalizedRangeStartDate)
    }

    private func isRangeEnd(_ date: Date) -> Bool {
        showsDateRange && calendar.isDate(date, inSameDayAs: normalizedRangeEndDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        guard showsDateRange else {
            return false
        }

        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= normalizedRangeStartDate && normalizedDate <= normalizedRangeEndDate
    }

    private func hasEvent(on date: Date) -> Bool {
        eventDates.contains { calendar.isDate($0, inSameDayAs: date) }
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
    let showsDateRange: Bool
    let eventDates: [Date]
    let eventTint: Color
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
                            hasEvent: hasEvent(on: date),
                            eventTint: eventTint,
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
        showsDateRange && calendar.isDate(date, inSameDayAs: normalizedRangeStartDate)
    }

    private func isRangeEnd(_ date: Date) -> Bool {
        showsDateRange && calendar.isDate(date, inSameDayAs: normalizedRangeEndDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        guard showsDateRange else {
            return false
        }

        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= normalizedRangeStartDate && normalizedDate <= normalizedRangeEndDate
    }

    private func hasEvent(on date: Date) -> Bool {
        eventDates.contains { calendar.isDate($0, inSameDayAs: date) }
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
    let hasEvent: Bool
    let eventTint: Color
    let calendar: Calendar

    var body: some View {
        ZStack {
            rangeConnector

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 17, weight: isEmphasized ? .semibold : .regular))
                .frame(width: LayoutMetrics.calendarDayCellSize, height: LayoutMetrics.calendarDayCellSize)
                .foregroundStyle(foregroundStyle)
                .background(endpointBackground, in: Circle())

            if hasEvent {
                Circle()
                    .fill(isEmphasized ? Color.white : eventTint)
                    .frame(width: 4, height: 4)
                    .offset(y: 14)
            }
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
    let excludedTimeRule: ExcludedTimeRule
    let isResponseMode: Bool
    let animatesResponseReveal: Bool
    let allowsAvailabilityEditing: Bool
    let selectedAvailabilityMode: AvailabilityMode
    let rowHeight: CGFloat
    let bottomContentInset: CGFloat
    let calendar: Calendar
    let onTapSlot: (AvailabilitySlot) -> Void
    let onCommitSlots: (Set<AvailabilitySlot>) -> Void
    let onEditAvailabilityBlock: (AvailabilityBlockDetail) -> Void
    let onMovePage: (Int) -> Void
    let onResponseRevealComplete: () -> Void

    @State private var currentTime = Date()
    @State private var dragStartSlot: AvailabilitySlot?
    @State private var dragPreviewSlots: Set<AvailabilitySlot> = []
    @State private var selectedAvailabilityBlock: AvailabilityBlockDetail?
    @State private var selectedTeamResponse: TeamResponseDetail?
    @State private var responseRevealCounts: [String: Int] = [:]
    @State private var responseRevealPlayedSignature = ""

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
                            excludedTimeLayer(layout: gridLayout)
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
        .onAppear {
            prepareTeamResponseRevealIfNeeded()
        }
        .onChange(of: isResponseMode) { _, _ in
            prepareTeamResponseRevealIfNeeded()
        }
        .onChange(of: responseRevealSignature) { _, _ in
            prepareTeamResponseRevealIfNeeded()
        }
        .onChange(of: animatesResponseReveal) { _, _ in
            prepareTeamResponseRevealIfNeeded(forceReplay: true)
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
                .presentationDetents(availabilityDetailDetents(for: detail))
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedTeamResponse) { detail in
            TeamResponseDetailSheet(detail: detail, calendar: calendar)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func availabilityDetailDetents(for detail: AvailabilityBlockDetail) -> Set<PresentationDetent> {
        let reason = detail.reason.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !reason.isEmpty else {
            return [.height(292)]
        }

        if reason.count > 80 {
            return [.height(410), .large]
        }

        return [.height(370)]
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
                    let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)

                    if !isExcludedSlot(slot) {
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
        }
        .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func excludedTimeLayer(layout: ScheduleGridLayout) -> some View {
        let excludedHours = (workStartHour..<workEndHour).filter { hour in
            visibleDates.contains { date in
                excludedTimeRule.excludes(hour: hour, date: date, calendar: calendar)
            }
        }

        if !excludedHours.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(excludedHours, id: \.self) { hour in
                    ForEach(excludedDateGroups(for: hour), id: \.self) { group in
                        let firstIndex = group.lowerBound
                        let lastIndex = group.upperBound
                        let xStart = layout.xOffset(for: firstIndex)
                        let width = layout.xOffset(for: lastIndex) + layout.columnWidth - xStart
                        let height = rowHeight - 3

                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(uiColor: .systemGray6).opacity(0.42))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.06), lineWidth: 0.7)
                            }
                            .overlay {
                                if width > 96 {
                                    Text(excludedTimeRule.blockTitle)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(uiColor: .tertiaryLabel).opacity(0.78))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: width, height: height)
                            .position(
                                x: xStart + width / 2,
                                y: yCenter(for: hour, height: height)
                            )
                    }
                }
            }
            .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
        }
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
                let totalCount = max(block.summary.totalCount, 1)
                let revealedCount = min(responseRevealCounts[block.id] ?? min(1, totalCount), totalCount)
                let isComplete = revealedCount >= totalCount
                let blockOpacity = isComplete ? 1.0 : 0.38

                Text("응답 \(revealedCount)/\(totalCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isComplete ? Color(uiColor: .secondaryLabel).opacity(0.76) : Color(uiColor: .tertiaryLabel).opacity(0.62))
                    .contentTransition(.numericText())
                .frame(width: layout.columnWidth, height: height)
                .background(
                    Color(uiColor: .tertiarySystemFill).opacity(isComplete ? 0.56 : 0.12),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(isComplete ? 0.18 : 0.04), lineWidth: 0.8)
                }
                .opacity(blockOpacity)
                .overlay(alignment: .topTrailing) {
                    if isComplete && block.summary.unavailableCount > 0 {
                        Circle()
                            .fill(Color(uiColor: .systemRed).opacity(0.82))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                            .transition(.opacity)
                    }
                }
                .overlay {
                    responseHourTicks(for: block, height: height, width: layout.columnWidth)
                        .opacity(isComplete ? 1 : 0.45)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    guard isComplete else {
                        return
                    }

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
                .animation(.easeInOut(duration: 0.42), value: isComplete)
                .animation(.easeInOut(duration: 0.32), value: revealedCount)
            }
        }
        .frame(width: layout.width, height: gridHeight, alignment: .topLeading)
        .animation(blockAnimation, value: teamResponseBlocks)
    }

    private var responseRevealSignature: String {
        guard isResponseMode else {
            return "idle"
        }

        return teamResponseBlocks.map(\.id).joined(separator: "|")
    }

    private func prepareTeamResponseRevealIfNeeded(forceReplay: Bool = false) {
        guard isResponseMode else {
            responseRevealCounts = [:]
            responseRevealPlayedSignature = ""
            return
        }

        let blocks = teamResponseBlocks
        let signature = responseRevealSignature

        guard !blocks.isEmpty, forceReplay || responseRevealPlayedSignature != signature else {
            return
        }

        responseRevealPlayedSignature = signature

        guard animatesResponseReveal else {
            responseRevealCounts = Dictionary(
                uniqueKeysWithValues: blocks.map { block in
                    (block.id, min(1, max(block.summary.totalCount, 1)))
                }
            )
            return
        }

        responseRevealCounts = Dictionary(
            uniqueKeysWithValues: blocks.map { block in
                (block.id, min(1, max(block.summary.totalCount, 1)))
            }
        )

        var latestCompletionDelay: Double = 0

        for (blockIndex, block) in blocks.enumerated() {
            let totalCount = max(block.summary.totalCount, 1)
            let sequence = responseRevealSequence(for: totalCount, block: block, index: blockIndex)
            let baseDelay = responseRevealBaseDelay(for: block, index: blockIndex)

            for (stepIndex, count) in sequence.enumerated() {
                let delay = baseDelay + Double(stepIndex) * 0.62
                latestCompletionDelay = max(latestCompletionDelay, delay)

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard isResponseMode, responseRevealPlayedSignature == signature else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.46)) {
                        responseRevealCounts[block.id] = count
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + latestCompletionDelay + 0.42) {
            guard isResponseMode, responseRevealPlayedSignature == signature else {
                return
            }

            onResponseRevealComplete()
        }
    }

    private func responseRevealBaseDelay(for block: TeamResponseBlock, index: Int) -> Double {
        let mixedValue = abs((block.dayIndex * 37 + block.startHour * 17 + block.endHour * 11 + index * 13) % 19)
        return 0.28 + Double(mixedValue) * 0.14
    }

    private func responseRevealSequence(for totalCount: Int, block: TeamResponseBlock, index: Int) -> [Int] {
        guard totalCount > 1 else {
            return [1]
        }

        let seed = abs(block.dayIndex * 31 + block.startHour * 19 + block.endHour * 7 + index * 11)
        let patterns = [
            [1, 3, totalCount],
            [2, 5, totalCount],
            [1, 2, 5, totalCount],
            [3, totalCount],
            [1, 4, totalCount],
            [2, 3, totalCount]
        ]
        let rawPattern = patterns[seed % patterns.count]
        var values: [Int] = []

        for count in rawPattern {
            let normalizedCount = min(max(count, 1), totalCount)

            if values.last != normalizedCount {
                values.append(normalizedCount)
            }
        }

        return values
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
                guard !isResponseMode, allowsAvailabilityEditing else {
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
                guard !isResponseMode, allowsAvailabilityEditing else {
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

        let slot = AvailabilitySlot(date: calendar.startOfDay(for: visibleDates[dayIndex]), hour: hour)

        guard !isExcludedSlot(slot) else {
            return nil
        }

        return slot
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
                let slot = AvailabilitySlot(date: date, hour: hour)

                if !isExcludedSlot(slot) {
                    slots.insert(slot)
                }
            }
        }

        return slots
    }

    private func excludedDateGroups(for hour: Int) -> [ClosedRange<Int>] {
        var groups: [ClosedRange<Int>] = []
        var groupStart: Int?
        var previousIndex: Int?

        for (index, date) in visibleDates.enumerated() {
            let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)

            guard isExcludedSlot(slot) else {
                if let start = groupStart, let previous = previousIndex {
                    groups.append(start...previous)
                }

                groupStart = nil
                previousIndex = nil
                continue
            }

            if groupStart == nil {
                groupStart = index
            }

            previousIndex = index
        }

        if let start = groupStart, let previous = previousIndex {
            groups.append(start...previous)
        }

        return groups
    }

    private func isExcludedSlot(_ slot: AvailabilitySlot) -> Bool {
        excludedTimeRule.excludes(hour: slot.hour, date: slot.date, calendar: calendar)
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
        guard !isExcludedSlot(slot) else {
            return nil
        }

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
    let requiredAvailableNames: Set<String>
    let requiredAvailableCount: Int
    let requiredUnavailableCount: Int
    let optionalAvailableCount: Int
    let optionalUnavailableCount: Int
    let requiredTotalCount: Int
    let optionalTotalCount: Int

    var totalCount: Int {
        availableCount + burdenCount + unavailableCount
    }

    var availableCount: Int {
        availableNames.count
    }

    var burdenCount: Int {
        burdenMembers.count
    }

    var weightedBurdenScore: Int {
        burdenMembers.reduce(0) { $0 + $1.category.weight }
    }

    var burdenCategorySummaries: [BurdenCategorySummary] {
        BurdenCategory.allCases.compactMap { category in
            let count = burdenMembers.filter { $0.category == category }.count
            guard count > 0 else {
                return nil
            }

            return BurdenCategorySummary(category: category, count: count)
        }
    }

    var unavailableCount: Int {
        unavailableMembers.count
    }

    var requiredParticipationText: String {
        "\(requiredAvailableCount)/\(requiredTotalCount) 필참"
    }

    var optionalParticipationText: String {
        "\(optionalAvailableCount)/\(optionalTotalCount) 선택"
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
            .map { "\($0.name):\($0.reason):\($0.isRequired)" }
            .sorted()
            .joined(separator: ",")
        let unavailable = unavailableMembers
            .map { "\($0.name):\($0.reason):\($0.isRequired)" }
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

    func finalCandidatePresentationSummary(rank: Int) -> TeamResponseSummary {
        let reason: String
        let fallbackName: String

        if rank == 0 {
            reason = "집중: 연속된 일정으로 집중력이 떨어질 수 있어\n짧은 회복 시간이 필요합니다."
            fallbackName = "송승아"
        } else {
            reason = "일정: 바로 전 고객 피드백 정리 마감과 붙어 있어\n회의 준비 시간이 거의 없습니다."
            fallbackName = "김민준"
        }

        let existingBurden = burdenMembers.first
        let burdenName = existingBurden?.name ?? availableNames.last ?? fallbackName
        let isRequired = existingBurden?.isRequired ?? requiredAvailableNames.contains(burdenName)
        let adjustedBurden = [TeamResponseReason(name: burdenName, reason: reason, isRequired: isRequired)]
        let recoveredAvailable = burdenMembers
            .map(\.name)
            .filter { $0 != burdenName }
        let adjustedAvailable = Array(Set(availableNames + recoveredAvailable))
            .filter { $0 != burdenName }
            .sorted()

        return TeamResponseSummary(
            availableNames: adjustedAvailable,
            burdenMembers: adjustedBurden,
            unavailableMembers: unavailableMembers,
            requiredAvailableNames: requiredAvailableNames,
            requiredAvailableCount: requiredAvailableCount,
            requiredUnavailableCount: requiredUnavailableCount,
            optionalAvailableCount: optionalAvailableCount,
            optionalUnavailableCount: optionalUnavailableCount,
            requiredTotalCount: requiredTotalCount,
            optionalTotalCount: optionalTotalCount
        )
    }

    static func makeSummaries(for meeting: HomeMeeting, dates: [Date], calendar: Calendar) -> [AvailabilitySlot: TeamResponseSummary] {
        let fallbackNames = ["나", "김민준", "이서연", "오유진", "송승아", "박도윤"]
        let memberNames = meeting.memberInitials.isEmpty ? fallbackNames : meeting.memberInitials
        let normalizedNames = (0..<max(meeting.memberCount, memberNames.count)).map { index in
            index < memberNames.count ? memberNames[index] : "팀원 \(index)"
        }
        let burdenReasons = [
            "일정: 바로 전 디자인 리뷰가 끝난 직후라\n회의 준비 시간이 거의 없습니다.",
            "일정: 고객 피드백 정리 마감과 붙어 있어\n참석은 가능하지만 집중이 분산됩니다.",
            "이동: 외부 사용자 인터뷰 후 복귀 중이라\n10분 이상 늦을 수 있습니다.",
            "일정: 촬영 장비 반납 일정과 붙어 있어\n회의 준비 시간이 부족합니다.",
            "집중: 집중 업무 직후라 중요한 의사결정에\n바로 참여하기 부담됩니다.",
            "집중: 피로가 누적되어 회의에 집중하기\n어려운 시간대입니다.",
            "개인: 어린이집 하원 연락을 확인해야 해서\n중간 이탈 가능성이 있습니다.",
            "개인: 병원 예약 전후라 참석은 가능하지만\n안정적으로 참여하기 어렵습니다."
        ]
        let unavailableReasons = [
            "일정: 이미 확정된 고객사 리뷰 회의와 겹쳐\n참석할 수 없습니다.",
            "일정: 스프린트 최종 승인 회의가 고정되어\n시간 변경이 어렵습니다.",
            "이동: 외근 미팅 장소에서 복귀 중인 시간이라\n온라인 참석도 어렵습니다.",
            "이동: 사용자 인터뷰 이동 시간과 겹쳐\n회의 시작 전에 도착할 수 없습니다.",
            "개인: 병원 예약이 확정되어\n해당 시간에는 응답이 어렵습니다.",
            "개인: 가족 일정으로 자리를 비워야 해서\n회의 참여가 불가능합니다."
        ]
        var summaries: [AvailabilitySlot: TeamResponseSummary] = [:]

        for (dayIndex, date) in dates.enumerated() {
            for hour in 9..<18 {
                let slot = AvailabilitySlot(date: calendar.startOfDay(for: date), hour: hour)
                guard !meeting.excludedTimeRule.excludes(hour: hour, date: date, calendar: calendar) else {
                    continue
                }

                var available: [String] = []
                var burden: [TeamResponseReason] = []
                var unavailable: [TeamResponseReason] = []
                var requiredAvailableNames: Set<String> = []
                var requiredAvailableCount = 0
                var requiredUnavailableCount = 0
                var optionalAvailableCount = 0
                var optionalUnavailableCount = 0

                for (memberIndex, name) in normalizedNames.enumerated() {
                    let isRequired = meeting.isRequiredMember(at: memberIndex)

                    if memberIndex == 0, let hostEntry = meeting.hostAvailabilityEntries[slot] {
                        switch hostEntry.mode {
                        case .available:
                            available.append(name)
                            if isRequired {
                                requiredAvailableNames.insert(name)
                                requiredAvailableCount += 1
                            } else {
                                optionalAvailableCount += 1
                            }
                        case .burden:
                            burden.append(TeamResponseReason(name: name, reason: hostEntry.reason ?? "참석은 가능하지만 앞뒤 일정 조정이 필요합니다.", isRequired: isRequired))
                            if isRequired {
                                requiredAvailableCount += 1
                            } else {
                                optionalAvailableCount += 1
                            }
                        case .unavailable:
                            unavailable.append(TeamResponseReason(name: name, reason: hostEntry.reason ?? "이미 확정된 일정과 겹쳐 참석이 어렵습니다.", isRequired: isRequired))
                            if isRequired {
                                requiredUnavailableCount += 1
                            } else {
                                optionalUnavailableCount += 1
                            }
                        }
                        continue
                    }

                    let seed = dayIndex * 11 + hour + memberIndex * 3

                    if seed % 9 == 0 {
                        unavailable.append(
                            TeamResponseReason(
                                name: name,
                                reason: unavailableReasons[seed % unavailableReasons.count],
                                isRequired: isRequired
                            )
                        )
                        if isRequired {
                            requiredUnavailableCount += 1
                        } else {
                            optionalUnavailableCount += 1
                        }
                    } else if seed % 5 == 0 {
                        burden.append(
                            TeamResponseReason(
                                name: name,
                                reason: burdenReasons[seed % burdenReasons.count],
                                isRequired: isRequired
                            )
                        )
                        if isRequired {
                            requiredAvailableCount += 1
                        } else {
                            optionalAvailableCount += 1
                        }
                    } else {
                        available.append(name)
                        if isRequired {
                            requiredAvailableNames.insert(name)
                            requiredAvailableCount += 1
                        } else {
                            optionalAvailableCount += 1
                        }
                    }
                }

                summaries[slot] = TeamResponseSummary(
                    availableNames: available,
                    burdenMembers: burden,
                    unavailableMembers: unavailable,
                    requiredAvailableNames: requiredAvailableNames,
                    requiredAvailableCount: requiredAvailableCount,
                    requiredUnavailableCount: requiredUnavailableCount,
                    optionalAvailableCount: optionalAvailableCount,
                    optionalUnavailableCount: optionalUnavailableCount,
                    requiredTotalCount: meeting.requiredMemberCount,
                    optionalTotalCount: meeting.optionalMemberCount
                )
            }
        }

        return summaries
    }
}

private struct BurdenCategorySummary: Identifiable, Equatable {
    let category: BurdenCategory
    let count: Int

    var id: String {
        category.rawValue
    }
}

private enum BurdenCategory: String, CaseIterable, Identifiable {
    case schedule
    case movement
    case focus
    case personal

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .schedule:
            return "일정"
        case .movement:
            return "이동"
        case .focus:
            return "집중"
        case .personal:
            return "개인"
        }
    }

    var burdenTitle: String {
        "\(title) 부담"
    }

    var weight: Int {
        switch self {
        case .schedule, .movement:
            return 3
        case .personal:
            return 2
        case .focus:
            return 1
        }
    }

    var color: Color {
        switch self {
        case .schedule:
            return Color(uiColor: .systemRed)
        case .movement:
            return Color(uiColor: .systemOrange)
        case .focus:
            return Color(uiColor: .systemTeal)
        case .personal:
            return Color(uiColor: .systemPurple)
        }
    }

    var symbolName: String {
        switch self {
        case .schedule:
            return "calendar.badge.clock"
        case .movement:
            return "arrow.triangle.swap"
        case .focus:
            return "brain.head.profile"
        case .personal:
            return "person.fill"
        }
    }

    static func classify(reason: String) -> BurdenCategory {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        let explicitPrefixes: [(prefixes: [String], category: BurdenCategory)] = [
            (["집중:", "집중 부담:", "집중도:", "집중도 부담:", "컨디션:", "컨디션 부담:"], .focus),
            (["이동:", "이동 부담:"], .movement),
            (["일정:", "일정 부담:"], .schedule),
            (["개인:", "개인 부담:"], .personal)
        ]

        for mapping in explicitPrefixes where mapping.prefixes.contains(where: normalizedReason.hasPrefix) {
            return mapping.category
        }

        if reason.contains("개인 일정") || reason.contains("병원") || reason.contains("가족") || reason.contains("하원") {
            return .personal
        }

        if reason.contains("점심") || reason.contains("집중") || reason.contains("피곤") || reason.contains("피로") || reason.contains("졸") || reason.contains("컨디션") || reason.contains("회복") {
            return .focus
        }

        if reason.contains("이동") || reason.contains("외근") || reason.contains("복귀") || reason.contains("도착") || reason.contains("장비") || reason.contains("인터뷰") {
            return .movement
        }

        if reason.contains("회의") || reason.contains("일정") || reason.contains("붙어") || reason.contains("확정") || reason.contains("마감") || reason.contains("승인") || reason.contains("고객") {
            return .schedule
        }

        return .personal
    }
}

private enum ResponseReasonFormatter {
    static func displayText(from reason: String) -> String {
        let prefixes = [
            "부담:", "불가:", "가능:",
            "일정:", "이동:", "집중:", "집중도:", "컨디션:", "개인:",
            "일정 부담:", "이동 부담:", "집중 부담:", "집중도 부담:", "컨디션 부담:", "개인 부담:",
            "일정 불가:", "이동 불가:", "집중도 불가:", "컨디션 불가:", "개인 불가:"
        ]
        var cleaned = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        for prefix in prefixes where cleaned.hasPrefix(prefix) {
            cleaned = String(cleaned.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return cleaned
    }
}

private struct TeamResponseReason: Equatable, Identifiable {
    let name: String
    let reason: String
    let isRequired: Bool

    var id: String {
        "\(name)-\(reason)-\(isRequired)"
    }

    var category: BurdenCategory {
        BurdenCategory.classify(reason: reason)
    }

    var displayReason: String {
        ResponseReasonFormatter.displayText(from: reason)
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
                        .foregroundStyle(detail.mode.tint)

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
                        HStack(spacing: 8) {
                            Text("사유")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)

                            if detail.mode == .burden {
                                burdenReasonChip
                            }

                            Spacer(minLength: 0)
                        }

                        Text(displayReason)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 18)
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var displayReason: String {
        ResponseReasonFormatter.displayText(from: detail.reason)
    }

    private var burdenReasonCategory: BurdenCategory {
        BurdenCategory.classify(reason: detail.reason)
    }

    private var burdenReasonChip: some View {
        HStack(spacing: 5) {
            Image(systemName: burdenReasonCategory.symbolName)
                .pillChipIcon(color: detail.mode.tint)

            Text(burdenReasonCategory.burdenTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(detail.mode.tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(detail.mode.tint.opacity(0.1), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct TeamResponseDetailSheet: View {
    let detail: TeamResponseDetail
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var isAvailableListExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    responseSummaryCard

                    if detail.summary.hasConcern {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("확인 필요")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)

                            ForEach(detail.summary.unavailableMembers) { member in
                                responseIssueCard(
                                    member: member,
                                    status: "불가",
                                    tint: Color(uiColor: .systemRed)
                                )
                            }

                            ForEach(detail.summary.burdenMembers) { member in
                                responseIssueCard(
                                    member: member,
                                    status: "부담",
                                    tint: Color(uiColor: .systemOrange)
                                )
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .systemGreen))

                            Text("모든 참석자가 가능한 시간입니다")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    availableSummaryCard
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var responseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(dateText) · \(timeText)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(detail.summary.availableCount)/\(detail.summary.totalCount)")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("가능")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 7) {
                responseCountPill(
                    title: "가능",
                    count: detail.summary.availableCount,
                    tint: Color(uiColor: .systemGreen)
                )

                responseCountPill(
                    title: "부담",
                    count: detail.summary.burdenCount,
                    tint: Color(uiColor: .systemOrange)
                )

                responseCountPill(
                    title: "불가",
                    count: detail.summary.unavailableCount,
                    tint: Color(uiColor: .systemRed)
                )
            }

            Text(summaryMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var availableSummaryCard: some View {
        VStack(alignment: .leading, spacing: isAvailableListExpanded ? 12 : 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.94, blendDuration: 0.04)) {
                    isAvailableListExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("가능한 참석자")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(availableSummaryText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    AvatarStack(names: detail.summary.availableNames, maxVisible: 5)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isAvailableListExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.94), value: isAvailableListExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            availableParticipantList
                .frame(height: isAvailableListExpanded ? availableParticipantListHeight : 0, alignment: .top)
                .opacity(isAvailableListExpanded ? 1 : 0)
                .clipped()
                .allowsHitTesting(isAvailableListExpanded)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.94, blendDuration: 0.04), value: isAvailableListExpanded)
    }

    private var availableParticipantList: some View {
        VStack(spacing: 0) {
            ForEach(Array(detail.summary.availableNames.enumerated()), id: \.offset) { index, name in
                availableParticipantRow(name: name)

                if index < detail.summary.availableNames.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
    }

    private var availableParticipantListHeight: CGFloat {
        let rowCount = detail.summary.availableNames.count
        let dividerCount = max(rowCount - 1, 0)

        return CGFloat(rowCount) * 50 + CGFloat(dividerCount)
    }

    private func availableParticipantRow(name: String) -> some View {
        HStack(spacing: 12) {
            ProfileAvatar(
                name: name,
                fallback: initial(for: name),
                size: 36,
                tint: Color(uiColor: .systemGreen)
            )

            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("가능")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemGreen))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Color(uiColor: .systemGreen).opacity(0.12), in: Capsule())
        }
        .frame(height: 50)
    }

    private func responseCountPill(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text("\(title) \(count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(tint.opacity(count == 0 ? 0.06 : 0.12), in: Capsule())
    }

    private func responseIssueCard(member: TeamResponseReason, status: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(tint.opacity(0.76))
                .frame(width: 5)
                .padding(.vertical, 6)

            ProfileAvatar(
                name: member.name,
                fallback: initial(for: member.name),
                size: 42,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(member.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    responseIssueCategoryChip(member.category, status: status, tint: tint)

                    Spacer(minLength: 0)
                }

                Text(member.displayReason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func responseIssueCategoryChip(_ category: BurdenCategory, status: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: responseIssueChipSymbol(category, status: status))
                .pillChipIcon(color: tint)

            Text(responseIssueChipTitle(category, status: status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(tint.opacity(0.1), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func responseIssueChipTitle(_ category: BurdenCategory, status: String) -> String {
        guard status == "부담" else {
            return status
        }

        return category.burdenTitle
    }

    private func responseIssueChipSymbol(_ category: BurdenCategory, status: String) -> String {
        guard status == "부담" else {
            return "xmark.circle.fill"
        }

        return category.symbolName
    }

    private var summaryMessage: String {
        if detail.summary.unavailableCount > 0 {
            return "불가 응답이 있어 확정 전 사유를 확인하는 것이 좋습니다."
        }

        if detail.summary.burdenCount > 0 {
            return "참석은 가능하지만 부담이 있는 팀원이 있습니다."
        }

        return "응답 기준으로 가장 안정적인 후보 시간입니다."
    }

    private var availableSummaryText: String {
        let names = detail.summary.availableNames

        guard !names.isEmpty else {
            return "가능한 참석자가 없습니다"
        }

        let visibleNames = names.prefix(3).joined(separator: ", ")

        if names.count > 3 {
            return "\(visibleNames) 외 \(names.count - 3)명 가능"
        }

        return "\(visibleNames) 가능"
    }

    private func initial(for name: String) -> String {
        String(name.prefix(1))
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
