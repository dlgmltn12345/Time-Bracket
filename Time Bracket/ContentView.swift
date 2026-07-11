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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
