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

struct AvailabilityEntry {
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
        static let recommendationProcessingHold = 1.5
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
        ZStack {
            ZStack {
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
                                withAnimation(processNavigationAnimation) {
                                    isEliminatedCandidatesPresented = true
                                }
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
                    } else if !isRecommendationProcessing {
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
                .opacity(isRecommendationProcessing ? 0 : 1)

                if isRecommendationProcessing {
                    RecommendationProcessingView()
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
            .offset(x: isEliminatedCandidatesPresented ? -34 : 0)
            .opacity(isEliminatedCandidatesPresented ? 0.9 : 1)

            if isEliminatedCandidatesPresented {
                CandidateSelectionProcessView(
                    stages: candidateSelectionStages,
                    responseSummaries: responseSummaries,
                    initialCandidateCount: derivationSlots.count,
                    calendar: calendar,
                    onDismiss: {
                        withAnimation(processNavigationAnimation) {
                            isEliminatedCandidatesPresented = false
                        }
                    }
                )
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isRecommendationProcessing)
        .animation(processNavigationAnimation, value: isEliminatedCandidatesPresented)
        .background(Color(uiColor: .systemBackground))
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

    private var processNavigationAnimation: Animation {
        .interactiveSpring(response: 0.44, dampingFraction: 0.92, blendDuration: 0.08)
    }

    private var isRecommendationProcessing: Bool {
        phase == .final && areNonFinalSlotsHidden && !isRecommendationReady
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
            return "참석하기 좋은 시간을 남길게요"
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

extension View {
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
        VStack(spacing: 0) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color(uiColor: .systemBlue))

            Text("추천안을 정리하고 있어요")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 18)

            Text("남은 후보를 비교해 가장 안정적인 시간을 찾고 있어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
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
        "location.fill"
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
                .symbolRenderingMode(.monochrome)
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
    let onDismiss: () -> Void

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
                    Button(action: onDismiss) {
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

struct DerivationResponseSlot: Identifiable, Hashable {
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

struct DerivationResponseBlock: Identifiable, Hashable {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
