import Combine
import SwiftUI
import UIKit

struct ExpandableCalendarView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let showsDateRange: Bool
    let eventMarkers: [CalendarEventMarker]
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
                eventMarkers: eventMarkers,
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
                eventMarkers: eventMarkers,
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

struct MonthCalendarView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let showsDateRange: Bool
    let eventMarkers: [CalendarEventMarker]
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
                            eventTints: eventTints(on: day.date),
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

    private func eventTints(on date: Date) -> [Color] {
        eventMarkers.compactMap { marker in
            calendar.isDate(marker.date, inSameDayAs: date) ? marker.tint : nil
        }
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

struct WeekStripView: View {
    let month: Date
    @Binding var selectedDate: Date?
    let rangeStartDate: Date
    let rangeEndDate: Date
    let showsDateRange: Bool
    let eventMarkers: [CalendarEventMarker]
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
                            eventTints: eventTints(on: date),
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

    private func eventTints(on date: Date) -> [Color] {
        eventMarkers.compactMap { marker in
            calendar.isDate(marker.date, inSameDayAs: date) ? marker.tint : nil
        }
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

struct CalendarDayCell: View {
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
    let eventTints: [Color]
    let calendar: Calendar

    var body: some View {
        ZStack {
            rangeConnector

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 17, weight: isEmphasized ? .semibold : .regular))
                .frame(width: LayoutMetrics.calendarDayCellSize, height: LayoutMetrics.calendarDayCellSize)
                .foregroundStyle(foregroundStyle)
                .background(endpointBackground, in: Circle())

            if !eventTints.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(eventTints.prefix(3).enumerated()), id: \.offset) { _, tint in
                        Circle()
                            .fill(isEmphasized ? Color.white : tint)
                            .frame(width: 4, height: 4)
                    }
                }
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

struct CalendarDragHandle: View {
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

struct ScheduleGridLayout {
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

struct ScheduleGridView: View {
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

struct AvailabilityBlock: Identifiable, Equatable {
    let dayIndex: Int
    let startHour: Int
    var endHour: Int
    let mode: AvailabilityMode
    let reason: String

    var id: String {
        "\(dayIndex)-\(startHour)-\(mode.rawValue)-\(reason)"
    }
}

struct TeamResponseBlock: Identifiable, Equatable {
    let dayIndex: Int
    let date: Date
    let startHour: Int
    var endHour: Int
    let summary: TeamResponseSummary

    var id: String {
        "\(dayIndex)-\(startHour)-\(endHour)-\(summary.mergeSignature)"
    }
}

struct TeamResponseSummary: Equatable {
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

struct BurdenCategorySummary: Identifiable, Equatable {
    let category: BurdenCategory
    let count: Int

    var id: String {
        category.rawValue
    }
}

enum BurdenCategory: String, CaseIterable, Identifiable {
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

enum ResponseReasonFormatter {
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

struct TeamResponseReason: Equatable, Identifiable {
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

struct AvailabilityBlockDetail: Identifiable {
    let id = UUID()
    let date: Date
    let startHour: Int
    let endHour: Int
    let mode: AvailabilityMode
    let reason: String
}

struct TeamResponseDetail: Identifiable {
    let id = UUID()
    let date: Date
    let startHour: Int
    let endHour: Int
    let summary: TeamResponseSummary
}

struct AvailabilityBlockDetailSheet: View {
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

struct TeamResponseDetailSheet: View {
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

struct ScheduleEventView: View {
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

struct AvailabilitySlot: Hashable {
    let date: Date
    let hour: Int
}

struct CalendarDisplayDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool

    var id: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }
}

struct ScheduleEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let startHour: Int
    let endHour: Int
}

struct CalendarEventMarker: Identifiable {
    let id: String
    let date: Date
    let tint: Color
}
