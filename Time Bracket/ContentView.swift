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
    @State private var meetings: [HomeMeeting] = HomeMeeting.existingMeetings
    @State private var selectedMeeting: HomeMeeting? = HomeMeeting.existingMeetings.first
    @State private var recentlyConfirmedMeetingID: String?
    @State private var isCreateMeetingPresented = false
    @State private var workspaceIdentity = UUID()

    private static let referenceDate = makeDate(year: 2026, month: 7, day: 15)
    private static let homeReferenceDate = makeDate(year: 2026, month: 7, day: 11)
    private static let referenceMonth = makeDate(year: 2026, month: 7, day: 1)
    private static let expandedCalendarHeight: CGFloat = 306
    private static let collapsedCalendarHeight: CGFloat = 86
    private static let events: [ScheduleEvent] = []

    private let calendar = Self.appCalendar

    var body: some View {
        TabView(selection: $selectedTab) {
            VStack(spacing: 0) {
                HomeHeader(
                    date: Self.homeReferenceDate,
                    onResetPrototype: resetPrototype
                )
                HomeView(
                    meetings: meetings,
                    referenceDate: Self.homeReferenceDate,
                    selectedMeetingID: selectedMeeting?.id,
                    recentlyConfirmedMeetingID: recentlyConfirmedMeetingID,
                    onCreateMeeting: presentCreateMeeting,
                    onSelectMeeting: openMeeting
                )
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
                calendarEventMarkers: confirmedCalendarEventMarkers,
                meeting: selectedMeeting,
                calendar: calendar,
                onShareWithMembers: shareHostAvailability,
                onCompareResponses: compareCandidateTimes,
                onConfirmMeeting: confirmMeeting
            )
            .id(workspaceIdentity)
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

    private var confirmedCalendarEventMarkers: [CalendarEventMarker] {
        meetings
            .filter { $0.status == .confirmed }
            .map { meeting in
                CalendarEventMarker(
                    id: meeting.id,
                    date: meeting.focusDate,
                    tint: meeting.iconTint
                )
            }
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
        recentlyConfirmedMeetingID = nil
        isCreateMeetingPresented = true
    }

    private func resetPrototype() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isCreateMeetingPresented = false

        withAnimation(.easeInOut(duration: 0.28)) {
            meetings = HomeMeeting.existingMeetings
            selectedMeeting = HomeMeeting.existingMeetings.first
            recentlyConfirmedMeetingID = nil
            selectedDate = nil
            displayedMonth = Self.referenceMonth
            calendarHeight = Self.expandedCalendarHeight
            workspaceIdentity = UUID()
            selectedTab = .home
        }
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
        recentlyConfirmedMeetingID = updatedMeeting.id
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
    let calendarEventMarkers: [CalendarEventMarker]
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
                    calendarEventMarkers: calendarEventMarkers,
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

enum LayoutMetrics {
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
    let calendarEventMarkers: [CalendarEventMarker]
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
    @State private var isConfirmedMeetingDetailPresented = false
    @State private var isConfirmedMeetingTransitioning = false
    @Namespace private var confirmedMeetingNamespace

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
                                eventMarkers: calendarEventMarkers,
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
                                        calendar: calendar,
                                        namespace: confirmedMeetingNamespace,
                                        isDetailPresented: isConfirmedMeetingDetailPresented,
                                        isTransitioning: isConfirmedMeetingTransitioning,
                                        onShowDetail: {
                                            withAnimation(.easeOut(duration: 0.1)) {
                                                isConfirmedMeetingTransitioning = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.92, blendDuration: 0.08)) {
                                                    isConfirmedMeetingDetailPresented = true
                                                }
                                            }
                                        }
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
                CalendarDerivationTransitionOverlay {
                    onCompareResponses(meeting.id, derivationCriteria)
                }
                    .transition(.opacity.animation(.easeInOut(duration: 0.22)))
                    .zIndex(10)
            }

            if isConfirmedCalendar && isConfirmedMeetingDetailPresented {
                ConfirmedMeetingDetailOverlay(
                    meeting: meeting,
                    namespace: confirmedMeetingNamespace,
                    onDismiss: {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.93, blendDuration: 0.08)) {
                            isConfirmedMeetingDetailPresented = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                            withAnimation(.easeIn(duration: 0.16)) {
                                isConfirmedMeetingTransitioning = false
                            }
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(.container, edges: isConfirmedCalendar ? .bottom : [])
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

        derivationCriteria = criteria
        withAnimation(.spring(response: 0.52, dampingFraction: 0.9, blendDuration: 0.06)) {
            isDerivationTransitionActive = true
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

struct DerivationCriteriaSheet: View {
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

struct DerivationCriteria: Equatable {
    var timePreference: DerivationTimePreference
    var avoidsEarlyMorning: Bool
    var avoidsAfterLunch: Bool
    var avoidsNearLeaving: Bool
    var priority: DerivationDecisionPriority

    static let `default` = DerivationCriteria(
        timePreference: .any,
        avoidsEarlyMorning: false,
        avoidsAfterLunch: false,
        avoidsNearLeaving: false,
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

enum DerivationTimePreference: String, CaseIterable, Identifiable {
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

enum DerivationDecisionPriority: String, CaseIterable, Identifiable {
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
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isOrbiting = false
    @State private var isPulsing = false
    @State private var isReady = false
    @State private var isReadyCopyVisible = false
    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var didSendCompletion = false
    @State private var animationTask: Task<Void, Never>?

    private let tint = Color(uiColor: .systemBlue)

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    analysisIndicator
                        .opacity(isReady ? 0 : 1)
                        .scaleEffect(isReady ? 0.94 : 1)

                    AnimatedConfirmationCheckmark(
                        circleProgress: circleProgress,
                        checkProgress: checkProgress,
                        tint: tint
                    )
                    .frame(width: 88, height: 88)
                    .opacity(isReady ? 1 : 0)
                    .scaleEffect(isReady ? 1 : 0.9)
                }
                .frame(width: 164, height: 164)
                .animation(.easeInOut(duration: 0.58), value: isReady)

                ZStack(alignment: .top) {
                    statusCopy(
                        title: "응답을 분석하고 있어요",
                        detail: "6명의 일정과 선택 기준을 비교하고 있어요."
                    )
                    .opacity(isReadyCopyVisible ? 0 : 1)
                    .offset(y: isReadyCopyVisible ? -5 : 0)

                    statusCopy(
                        title: "후보를 비교할 준비가 됐어요",
                        detail: "선택한 기준에 따라 가능한 시간을 살펴볼게요."
                    )
                    .opacity(isReadyCopyVisible ? 1 : 0)
                    .offset(y: isReadyCopyVisible ? 0 : 7)
                }
                .frame(height: 74, alignment: .top)
                .padding(.top, 28)
                .animation(.easeInOut(duration: 0.58), value: isReadyCopyVisible)
            }
            .offset(y: -24)
        }
        .accessibilityElement(children: .combine)
        .onAppear(perform: startAnimation)
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private var analysisIndicator: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.055), lineWidth: 1)
                .frame(width: 156, height: 156)

            Circle()
                .stroke(tint.opacity(0.09), lineWidth: 5)
                .frame(width: 126, height: 126)
                .scaleEffect(isPulsing ? 1.035 : 0.965)
                .opacity(isPulsing ? 0.72 : 1)
                .animation(
                    .easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Circle()
                .trim(from: 0.04, to: 0.28)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 126, height: 126)
                .rotationEffect(.degrees(isOrbiting ? 360 : 0))
                .animation(
                    .linear(duration: 1.28).repeatForever(autoreverses: false),
                    value: isOrbiting
                )

            Circle()
                .fill(tint)
                .frame(width: 72, height: 72)

            PhaseAnimator([0, 1, 2, 3]) { phase in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 6, height: barHeight(index: index, phase: phase))
                    }
                }
                .frame(height: 28, alignment: .bottom)
            } animation: { _ in
                .easeInOut(duration: 0.34)
            }
        }
    }

    private func statusCopy(title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(index: Int, phase: Int) -> CGFloat {
        let heights: [[CGFloat]] = [
            [7, 20, 11],
            [12, 8, 23],
            [20, 13, 7],
            [8, 22, 16]
        ]
        return heights[phase % heights.count][index]
    }

    private func startAnimation() {
        animationTask?.cancel()
        isReady = false
        isReadyCopyVisible = false
        circleProgress = 0
        checkProgress = 0
        didSendCompletion = false
        isOrbiting = false
        isPulsing = false

        guard !reduceMotion else {
            isReady = true
            isReadyCopyVisible = true
            circleProgress = 1
            checkProgress = 1
            completeOnce(after: 0.55)
            return
        }

        DispatchQueue.main.async {
            isOrbiting = true
            isPulsing = true
        }

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.55))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.58)) {
                isReady = true
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.58)) {
                isReadyCopyVisible = true
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.62)) {
                circleProgress = 1
            }

            try? await Task.sleep(for: .seconds(0.34))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.48)) {
                checkProgress = 1
            }

            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            completeOnce()
        }
    }

    private func completeOnce(after delay: Double = 0) {
        guard !didSendCompletion else { return }

        if delay > 0 {
            animationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                completeOnce()
            }
            return
        }

        didSendCompletion = true
        onComplete()
    }
}

private struct CalendarHeader: View {
    let title: String
    var backgroundColor: Color = Color(uiColor: .systemBackground)

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
        .background(backgroundColor)
    }

    private var headerTitle: some View {
        Text(title)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

private struct HomeHeader: View {
    let date: Date
    let onResetPrototype: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("회의 조율")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 12)

            Button(action: onResetPrototype) {
                ProfileAvatar(
                    name: "나",
                    fallback: "나",
                    size: 38,
                    tint: Color(uiColor: .systemIndigo),
                    borderColor: .clear,
                    borderWidth: 0
                )
                .padding(2.5)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.96), lineWidth: 1.5)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로토타입 초기화")
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: date)
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

struct MeetingContextBar: View {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
