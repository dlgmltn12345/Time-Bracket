import SwiftUI
import UIKit

struct ConfirmedDayScheduleView: View {
    let selectedDate: Date?
    let meeting: HomeMeeting
    let rowHeight: CGFloat
    let bottomContentInset: CGFloat
    let calendar: Calendar
    let namespace: Namespace.ID
    let isDetailPresented: Bool
    let isTransitioning: Bool
    let onShowDetail: () -> Void

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

                            if isMeetingDate && !isDetailPresented {
                                confirmedMeetingBlock(width: timelineWidth)
                            }
                        }
                        .frame(width: timelineWidth, height: gridHeight)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.top, 10)
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

        return Button(action: onShowDetail) {
            HStack(spacing: 12) {
                Image(systemName: meeting.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: Circle())
                    .matchedGeometryEffect(
                        id: "confirmed-meeting-\(meeting.id)-icon",
                        in: namespace
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(meeting.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .matchedGeometryEffect(
                            id: "confirmed-meeting-\(meeting.id)-title",
                            in: namespace
                        )

                    Text("\(meeting.timeRange) · \(meetingPlaceText)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .opacity(isTransitioning ? 0 : 1)
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
                .opacity(isTransitioning ? 0 : 1)
            }
            .padding(.horizontal, 12)
            .frame(width: max(width - 2, 0), height: height)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.09))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(tint.opacity(0.22), lineWidth: 0.8)
                    }
                    .matchedGeometryEffect(
                        id: "confirmed-meeting-\(meeting.id)-surface",
                        in: namespace
                    )
            }
        }
        .buttonStyle(.plain)
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

struct ConfirmedMeetingDetailOverlay: View {
    let meeting: HomeMeeting
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var showsDetails = false
    @State private var isDismissing = false

    private var tint: Color {
        meeting.iconTint
    }

    var body: some View {
        ZStack {
            Button(action: dismissDetail) {
                Color.black.opacity(showsDetails ? 0.12 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .transition(.opacity)

            VStack(alignment: .leading, spacing: 16) {
                detailHeader

                Group {
                    Divider()

                    VStack(spacing: 13) {
                        detailRow(
                            symbolName: "calendar",
                            title: "일정",
                            value: confirmedDateText,
                            iconTint: Color(uiColor: .systemBlue)
                        )
                        detailRow(
                            symbolName: "clock.fill",
                            title: "시간",
                            value: meeting.timeRange,
                            iconTint: Color(uiColor: .systemIndigo)
                        )
                        detailRow(
                            symbolName: "location.fill",
                            title: "장소",
                            value: locationSummary,
                            iconTint: Color(uiColor: .systemTeal)
                        )
                    }

                    if !meetingDetailText.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("회의 내용")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(meetingDetailText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Divider()

                    participantSection
                }
                .opacity(showsDetails ? 1 : 0)
                .offset(y: showsDetails ? 0 : 8)
            }
            .padding(18)
            .frame(maxWidth: 360, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(tint.opacity(0.16), lineWidth: 0.8)
                    }
                    .matchedGeometryEffect(
                        id: "confirmed-meeting-\(meeting.id)-surface",
                        in: namespace
                    )
            }
            .shadow(color: Color.black.opacity(showsDetails ? 0.12 : 0), radius: 24, y: 10)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.26)) {
                    showsDetails = true
                }
            }
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: meeting.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())
                .matchedGeometryEffect(
                    id: "confirmed-meeting-\(meeting.id)-icon",
                    in: namespace
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .matchedGeometryEffect(
                        id: "confirmed-meeting-\(meeting.id)-title",
                        in: namespace
                    )

                Text(meeting.sectionName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(showsDetails ? 1 : 0)
            }

            Spacer(minLength: 8)

            Button(action: dismissDetail) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .opacity(showsDetails ? 1 : 0)
        }
    }

    private func dismissDetail() {
        guard !isDismissing else {
            return
        }

        isDismissing = true
        withAnimation(.easeIn(duration: 0.12)) {
            showsDetails = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            onDismiss()
        }
    }

    private func detailRow(symbolName: String, title: String, value: String, iconTint: Color) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconTint)
                .frame(width: 28, height: 28)
                .background(iconTint.opacity(0.1), in: Circle())

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("참석자")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(meeting.memberCount)명")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: participantColumns, spacing: 8) {
                ForEach(meeting.memberInitials.indices, id: \.self) { index in
                    participantCell(name: meeting.memberInitials[index], index: index)
                }
            }
        }
    }

    private var participantColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8, alignment: .leading),
            GridItem(.flexible(), spacing: 8, alignment: .leading)
        ]
    }

    private func participantCell(name: String, index: Int) -> some View {
        HStack(spacing: 8) {
            ProfileAvatar(
                name: name,
                fallback: ProfileAsset.fallbackText(for: name),
                size: 30,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(meeting.isRequiredMember(at: index) ? "필참" : "선택")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var confirmedDateText: String {
        let month = Calendar.current.component(.month, from: meeting.focusDate)
        return "\(month)월 \(meeting.confirmedDay)일 (\(meeting.confirmedWeekday))"
    }

    private var locationSummary: String {
        let mode = subtitleComponents.first { $0 == "온라인" || $0 == "오프라인" }
        let location = meetingPlaceText

        guard let mode, mode != location else {
            return location
        }

        return "\(mode) · \(location)"
    }

    private var meetingDetailText: String {
        let ignoredValues = Set([meeting.sectionName, "온라인", "오프라인", meetingPlaceText])
        return subtitleComponents.first { !ignoredValues.contains($0) } ?? ""
    }

    private var meetingPlaceText: String {
        guard let modeIndex = subtitleComponents.firstIndex(where: { $0 == "온라인" || $0 == "오프라인" }) else {
            return meeting.sectionName
        }

        let locationIndex = subtitleComponents.index(after: modeIndex)
        return locationIndex < subtitleComponents.endIndex ? subtitleComponents[locationIndex] : subtitleComponents[modeIndex]
    }

    private var subtitleComponents: [String] {
        meeting.subtitle
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct WorkspaceHeader: View {
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

struct WorkspaceStatusCard: View {
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

struct ParticipantStatusBlock: View {
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

struct WorkspaceActionCard: View {
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

struct YearMonthWheelPicker: View {
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
