//
//  ContentView.swift
//  Time Bracket
//
//  Created by 이희수 on 6/30/26.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var selectedDate: Date? = Self.referenceDate
    @State private var displayedMonth = Self.referenceMonth
    @State private var selectedTab: TopTab = .calendar
    @State private var calendarHeight = Self.expandedCalendarHeight

    private static let referenceDate = makeDate(year: 2026, month: 7, day: 15)
    private static let referenceMonth = makeDate(year: 2026, month: 7, day: 1)
    private static let expandedCalendarHeight: CGFloat = 306
    private static let collapsedCalendarHeight: CGFloat = 86
    private static let events = [
        ScheduleEvent(
            id: "design-review",
            title: "Design Review",
            date: makeDate(year: 2026, month: 7, day: 15),
            startHour: 10,
            endHour: 11
        ),
        ScheduleEvent(
            id: "team-sync",
            title: "Team Sync",
            date: makeDate(year: 2026, month: 7, day: 16),
            startHour: 14,
            endHour: 15
        )
    ]

    private let calendar = Self.appCalendar

    var body: some View {
        TabView(selection: $selectedTab) {
            VStack(spacing: 0) {
                CalendarHeader(title: "홈")
                HomeView()
            }
            .tag(TopTab.home)
            .tabItem {
                Label("홈", systemImage: "house")
            }

            CalendarScreen(
                selectedDate: $selectedDate,
                displayedMonth: $displayedMonth,
                calendarHeight: $calendarHeight,
                expandedCalendarHeight: Self.expandedCalendarHeight,
                collapsedCalendarHeight: Self.collapsedCalendarHeight,
                events: Self.events,
                calendar: calendar
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

}

private enum TopTab {
    case home
    case calendar
}

private enum LayoutMetrics {
    static let horizontalPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 20
    static let calendarBottomPadding: CGFloat = 10
    static let calendarDayCellSize: CGFloat = 42
    static let timeAxisWidth: CGFloat = 36
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
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 0) {
            CalendarMonthHeader(
                title: navigationTitle,
                selectedDate: monthPickerDate,
                isTodaySelected: isTodaySelected,
                onTodayTap: moveToToday
            )

            GeometryReader { proxy in
                let calendarAnimation = Animation.interactiveSpring(
                    response: 0.42,
                    dampingFraction: 0.9,
                    blendDuration: 0.12
                )
                let handleBandHeight: CGFloat = 20
                let clampedCalendarHeight = min(
                    max(calendarHeight, collapsedCalendarHeight),
                    expandedCalendarHeight
                )
                let expansionProgress = (clampedCalendarHeight - collapsedCalendarHeight) / (expandedCalendarHeight - collapsedCalendarHeight)
                let scheduleHeight = max(proxy.size.height - clampedCalendarHeight - handleBandHeight, 0)

                VStack(spacing: 0) {
                    ZStack {
                        Color.primary

                        ExpandableCalendarView(
                            month: displayedMonth,
                            selectedDate: $selectedDate,
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
                            events: events,
                            calendar: calendar
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
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var navigationTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 2026)년 \(components.month ?? 7)월"
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

private struct HomeView: View {
    private let meetings = HomeMeeting.sampleData

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: HomeGridMetrics.gap) {
                NewMeetingCard()

                HomeSummaryBlock()

                MeetingGroupBlock(meetings: meetings.filter { $0.status != .confirmed })

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
    var body: some View {
        HStack(spacing: HomeGridMetrics.gap) {
            HomeMetricCard(
                title: "조율 중",
                value: "4",
                detail: "내가 만든 회의",
                symbolName: "calendar.badge.clock",
                tint: Color(uiColor: .systemBlue)
            )

            HomeMetricCard(
                title: "입력 필요",
                value: "2",
                detail: "초대받은 회의",
                symbolName: "pencil.and.list.clipboard",
                tint: Color(uiColor: .systemOrange)
            )
        }
    }
}

private struct MeetingGroupBlock: View {
    let meetings: [HomeMeeting]

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

            ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                MeetingRowCard(meeting: meeting)

                if index < meetings.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: HomeGridMetrics.cardShape)
    }
}

private struct MeetingRowCard: View {
    let meeting: HomeMeeting

    var body: some View {
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
    }
}

private struct NewMeetingCard: View {
    var body: some View {
        Button {
            print("Create meeting tapped")
        } label: {
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

private struct AvatarStack: View {
    let names: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Self.colors[index % Self.colors.count], in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 2)
                    }
            }
        }
        .frame(height: 28)
    }

    private static let colors = [
        Color(uiColor: .systemIndigo),
        Color(uiColor: .systemTeal),
        Color(uiColor: .systemPink),
        Color(uiColor: .systemGreen)
    ]
}

private struct HomeMeeting: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let dateRange: String
    let timeRange: String
    let memberCount: Int
    let respondedCount: Int
    let status: MeetingStatus
    let memberInitials: [String]
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

    static let sampleData = [
        HomeMeeting(
            id: "design-team-weekly",
            title: "디자인팀 회의",
            subtitle: "제품 방향성, IA, 화면 우선순위",
            dateRange: "7월 15일 - 18일",
            timeRange: "10:00 - 17:00",
            memberCount: 5,
            respondedCount: 3,
            status: .collecting,
            memberInitials: ["나", "PM", "FE", "BE"],
            confirmedDay: "15",
            confirmedWeekday: "수"
        ),
        HomeMeeting(
            id: "product-review",
            title: "제품 리뷰",
            subtitle: "MVP 범위 점검",
            dateRange: "7월 16일 - 17일",
            timeRange: "14:00 - 16:00",
            memberCount: 4,
            respondedCount: 4,
            status: .ready,
            memberInitials: ["나", "PO", "UX"],
            confirmedDay: "16",
            confirmedWeekday: "목"
        ),
        HomeMeeting(
            id: "research-sync",
            title: "리서치 싱크",
            subtitle: "인터뷰 결과 공유",
            dateRange: "7월 21일 - 22일",
            timeRange: "09:00 - 12:00",
            memberCount: 6,
            respondedCount: 2,
            status: .waiting,
            memberInitials: ["나", "UR", "DS"],
            confirmedDay: "21",
            confirmedWeekday: "화"
        ),
        HomeMeeting(
            id: "brand-check",
            title: "브랜드 체크인",
            subtitle: "가이드라인 확정",
            dateRange: "7월 14일",
            timeRange: "11:00 - 12:00",
            memberCount: 3,
            respondedCount: 3,
            status: .confirmed,
            memberInitials: ["나", "BD", "MK"],
            confirmedDay: "14",
            confirmedWeekday: "화"
        )
    ]
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
    let expansionProgress: CGFloat
    let calendar: Calendar

    var body: some View {
        ZStack(alignment: .top) {
            MonthCalendarView(
                month: month,
                selectedDate: $selectedDate,
                calendar: calendar
            )
            .opacity(expansionProgress)
            .scaleEffect(0.985 + 0.015 * expansionProgress, anchor: .top)
            .allowsHitTesting(expansionProgress > 0.5)

            WeekStripView(
                month: month,
                selectedDate: $selectedDate,
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
                            isSelected: selectedDate.map { calendar.isDate(day.date, inSameDayAs: $0) } ?? false,
                            isCurrentMonth: day.isCurrentMonth,
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

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
}

private struct WeekStripView: View {
    let month: Date
    @Binding var selectedDate: Date?
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
                            isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                            isCurrentMonth: true,
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

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let calendar: Calendar

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
            .frame(width: LayoutMetrics.calendarDayCellSize, height: LayoutMetrics.calendarDayCellSize)
            .foregroundStyle(foregroundStyle)
            .background(isSelected ? Color.primary : Color.clear, in: Circle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foregroundStyle: Color {
        if isSelected {
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

private struct ScheduleGridView: View {
    let selectedDate: Date?
    let events: [ScheduleEvent]
    let calendar: Calendar

    @State private var currentTime = Date()

    private let hours = Array(9...18)
    private let workStartHour = 9
    private let workEndHour = 18
    private let rowHeight: CGFloat = 42
    private let headerHeight: CGFloat = 26
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
                        selectedDateHeader
                            .frame(width: timelineWidth, height: headerHeight, alignment: .leading)

                        ZStack(alignment: .topLeading) {
                            gridBackground(width: timelineWidth)
                            eventLayer(width: timelineWidth)
                            currentTimeIndicator(width: timelineWidth)
                        }
                        .frame(width: timelineWidth, height: gridHeight)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 0)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onReceive(clock) { date in
            currentTime = date
        }
    }

    private var timeAxis: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: headerHeight)

            ZStack(alignment: .topTrailing) {
                ForEach(hours, id: \.self) { hour in
                    Text(timeLabel(hour))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: LayoutMetrics.timeAxisWidth, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .offset(y: CGFloat(hour - workStartHour) * rowHeight - 5)
                }
            }
            .frame(width: LayoutMetrics.timeAxisWidth, height: gridHeight, alignment: .topTrailing)
        }
    }

    private var selectedDateHeader: some View {
        Text(selectedDateHeaderText)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func gridBackground(width: CGFloat) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<hourIntervalCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(uiColor: .systemGray6).opacity(0.72))
                    .frame(width: width, height: rowHeight - 3)
            }
        }
    }

    @ViewBuilder
    private func eventLayer(width: CGFloat) -> some View {
        ForEach(eventsInSelectedDay) { event in
            ScheduleEventView(event: event)
                .frame(
                    width: max(width - 8, 0),
                    height: max(CGFloat(event.endHour - event.startHour) * rowHeight - 8, 32)
                )
                .offset(
                    x: 4,
                    y: CGFloat(event.startHour - workStartHour) * rowHeight + 4
                )
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(width: CGFloat) -> some View {
        if let yOffset = currentTimeOffset {
            HStack(spacing: 0) {
                Circle()
                    .fill(Color(uiColor: .systemRed))
                    .frame(width: 6, height: 6)
                    .offset(x: -3)

                Rectangle()
                    .fill(Color(uiColor: .systemRed))
                    .frame(width: width, height: 1)
            }
            .frame(width: width, height: 6, alignment: .leading)
            .offset(y: yOffset - 3)
            .accessibilityLabel("Current time \(currentTimeLabel)")
        }
    }

    private var eventsInSelectedDay: [ScheduleEvent] {
        guard let selectedDate else {
            return []
        }

        return events.filter { event in
            calendar.isDate(event.date, inSameDayAs: selectedDate)
        }
    }

    private var selectedDateHeaderText: String {
        guard let selectedDate else {
            return ""
        }

        return "\(selectedDate.formatted(.dateTime.weekday(.abbreviated))) \(calendar.component(.day, from: selectedDate))"
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

    private var currentTimeLabel: String {
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func timeLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
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
