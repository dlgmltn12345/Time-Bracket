import SwiftUI
import UIKit

struct HomeView: View {
    let meetings: [HomeMeeting]
    let referenceDate: Date
    let selectedMeetingID: String?
    let recentlyConfirmedMeetingID: String?
    let onCreateMeeting: () -> Void
    let onSelectMeeting: (HomeMeeting) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: HomeGridMetrics.gap) {
                HomeQuickCreateRow(onCreate: onCreateMeeting)

                if !userCreatedActiveMeetings.isEmpty {
                    HomeActiveMeetingListTile(
                        meetings: userCreatedActiveMeetings,
                        selectedMeetingID: selectedMeetingID,
                        onSelectMeeting: onSelectMeeting
                    )
                }

                if let priorityConfirmedMeeting {
                    HomeConfirmedMeetingTile(
                        meeting: priorityConfirmedMeeting,
                        isNewlyConfirmed: priorityConfirmedMeeting.id == recentlyConfirmedMeetingID,
                        onSelect: { onSelectMeeting(priorityConfirmedMeeting) }
                    )
                    .id(priorityConfirmedMeeting.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }

                if !otherConfirmedMeetings.isEmpty {
                    HomeScheduledMeetingListTile(
                        meetings: otherConfirmedMeetings,
                        newlyConfirmedMeetingID: recentlyConfirmedMeetingID,
                        onSelectMeeting: onSelectMeeting
                    )
                }

                if let pendingInvitation {
                    HomeResponseRequestCard(
                        meeting: pendingInvitation,
                        onSelect: { onSelectMeeting(pendingInvitation) }
                    )
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, HomeGridMetrics.topPadding)
            .padding(.bottom, 96)
            .animation(.spring(response: 0.42, dampingFraction: 0.9), value: homeStateKey)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var invitedMeetings: [HomeMeeting] {
        meetings.filter { $0.isInvitation && $0.stage == .hostAvailability }
    }

    private var userCreatedActiveMeetings: [HomeMeeting] {
        meetings.filter {
            $0.status != .confirmed && !$0.isInvitation && !$0.isPrototypeSeed
        }
    }

    private var confirmedMeetings: [HomeMeeting] {
        meetings
            .filter { $0.status == .confirmed }
            .sorted { meetingStartDate(for: $0) < meetingStartDate(for: $1) }
    }

    private var priorityConfirmedMeeting: HomeMeeting? {
        upcomingConfirmedMeetings.first
    }

    private var otherConfirmedMeetings: [HomeMeeting] {
        guard let priorityConfirmedMeeting else {
            return []
        }

        return upcomingConfirmedMeetings.filter { meeting in
            meeting.id != priorityConfirmedMeeting.id && isInHomeScheduleWindow(meeting.focusDate)
        }
    }

    private var pendingInvitation: HomeMeeting? {
        invitedMeetings.first
    }

    private var upcomingConfirmedMeetings: [HomeMeeting] {
        let referenceDay = homeCalendar.startOfDay(for: referenceDate)
        return confirmedMeetings.filter {
            homeCalendar.startOfDay(for: $0.focusDate) >= referenceDay
        }
    }

    private var homeStateKey: String {
        let meetingState = meetings
            .map { "\($0.id)-\($0.status.title)-\($0.respondedCount)" }
            .joined(separator: "|")
        return "\(meetingState)|recent:\(recentlyConfirmedMeetingID ?? "none")"
    }

    private var homeCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        return calendar
    }

    private func meetingStartDate(for meeting: HomeMeeting) -> Date {
        let startTime = meeting.timeRange
            .components(separatedBy: "-")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let components = startTime.split(separator: ":")
        let hour = components.first.flatMap { Int($0) } ?? 0
        let minute = components.dropFirst().first.flatMap { Int($0) } ?? 0

        return homeCalendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: meeting.focusDate
        ) ?? meeting.focusDate
    }

    private func isInHomeScheduleWindow(_ date: Date) -> Bool {
        let startDate = homeCalendar.startOfDay(for: referenceDate)
        guard let endDate = homeCalendar.date(byAdding: .day, value: 7, to: startDate) else {
            return false
        }

        let meetingDate = homeCalendar.startOfDay(for: date)
        return meetingDate >= startDate && meetingDate < endDate
    }
}
enum HomeGridMetrics {
    static let gap: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let primaryHeight: CGFloat = 218
    static let featureHeight: CGFloat = 218
    static let confirmedHeight: CGFloat = 176
    static let commandHeight: CGFloat = 66
    static let pendingHeight: CGFloat = 72
    static let responseRequestHeight: CGFloat = 94
    static let topBentoHeight: CGFloat = 244
    static let compactStatusHeight: CGFloat = 116
    static let weekStripHeight: CGFloat = 112
    static let bottomBentoHeight: CGFloat = 136
    static let topPadding: CGFloat = 8

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct HomePriorityTaskCard: View {
    let meeting: HomeMeeting
    let isRecentlyConfirmed: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                Text(stateTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)

                Text(stateValue)
                    .font(.system(size: 33, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 8)

                Text(stateCaption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                Spacer(minLength: 12)

                Text(meeting.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 14)
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                HomeGridMetrics.cardShape
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(HomeGridMetrics.cardShape.fill(tint.opacity(0.09)))
            }
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        if isRecentlyConfirmed { return Color(uiColor: .systemGreen) }

        switch meeting.stage {
        case .hostAvailability:
            return Color(uiColor: .systemOrange)
        case .collectingResponses:
            return Color(uiColor: .systemIndigo)
        case .bracketReview:
            return Color(uiColor: .systemPurple)
        case .confirmed:
            return Color(uiColor: .systemGreen)
        }
    }

    private var stateTitle: String {
        if isRecentlyConfirmed { return "회의 확정" }

        switch meeting.stage {
        case .hostAvailability:
            return meeting.isInvitation ? "내 입력 필요" : "내 시간 입력"
        case .collectingResponses:
            return "응답 수집 중"
        case .bracketReview:
            return "도출 준비 완료"
        case .confirmed:
            return "다가오는 회의"
        }
    }

    private var stateValue: String {
        if isRecentlyConfirmed || meeting.stage == .confirmed {
            let startTime = meeting.timeRange.components(separatedBy: " - ").first ?? meeting.timeRange
            return "\(meeting.confirmedWeekday) \(startTime)"
        }

        switch meeting.stage {
        case .hostAvailability:
            return "D-1"
        case .collectingResponses, .bracketReview:
            return "\(meeting.respondedCount)/\(meeting.memberCount)"
        case .confirmed:
            return meeting.timeRange
        }
    }

    private var stateCaption: String {
        if isRecentlyConfirmed { return "일정이 캘린더에 반영됐어요" }

        switch meeting.stage {
        case .hostAvailability:
            return "응답 마감까지"
        case .collectingResponses:
            return "팀원 응답"
        case .bracketReview:
            return "모든 응답 완료"
        case .confirmed:
            return meeting.dateRange
        }
    }

    private var actionTitle: String {
        if isRecentlyConfirmed { return "일정 확인" }

        switch meeting.stage {
        case .hostAvailability:
            return "시간 입력"
        case .collectingResponses:
            return "응답 확인"
        case .bracketReview:
            return "회의 도출"
        case .confirmed:
            return "일정 확인"
        }
    }
}

struct HomePriorityCreateCard: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            VStack(alignment: .leading, spacing: 0) {
                Text("새 회의")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .padding(.top, 14)

                Spacer(minLength: 12)

                Text("새 회의 조율")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("후보 기간과 참석자를 설정하세요")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 3)
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}

struct HomeNextConfirmedCompactCard: View {
    let meeting: HomeMeeting?
    let expandsVertically: Bool
    let onSelect: (() -> Void)?

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("다음 확정")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemGreen))

                if let meeting {
                    let startTime = meeting.timeRange.components(separatedBy: " - ").first ?? meeting.timeRange

                    Text("\(meeting.confirmedWeekday) \(startTime)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .padding(.top, 7)

                    Text(meeting.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(expandsVertically ? 2 : 1)
                        .padding(.top, 3)
                } else {
                    Text("일정 없음")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.top, 8)
                }

                if expandsVertically {
                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                HomeGridMetrics.cardShape
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(HomeGridMetrics.cardShape.fill(Color(uiColor: .systemGreen).opacity(0.08)))
            }
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }
}

struct HomeResponseWaitingCompactCard: View {
    let meeting: HomeMeeting

    var body: some View {
        Button {
            print("Remind members for \(meeting.title)")
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("응답 대기")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemIndigo))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(meeting.remainingCount)")
                        .font(.system(size: 27, weight: .semibold))
                        .monospacedDigit()

                    Text("명")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemIndigo))
                }
                .foregroundStyle(.primary)
                .padding(.top, 6)

                Spacer(minLength: 4)

                Label("다시 요청", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemIndigo))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                HomeGridMetrics.cardShape
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(HomeGridMetrics.cardShape.fill(Color(uiColor: .systemIndigo).opacity(0.08)))
            }
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}

struct HomeWeekStripCard: View {
    let meetings: [HomeMeeting]
    private let weekdays = ["월", "화", "수", "목", "금"]
    private let days = [13, 14, 15, 16, 17]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이번 주")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("확정 · 조율 일정")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }

            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { index in
                    VStack(spacing: 5) {
                        Text(weekdays[index])
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("\(days[index])")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        HStack(spacing: 3) {
                            ForEach(Array(colors(for: days[index]).prefix(2).enumerated()), id: \.offset) { _, color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.weekStripHeight, maxHeight: HomeGridMetrics.weekStripHeight, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
    }

    private func colors(for day: Int) -> [Color] {
        let confirmedColors = meetings.compactMap { meeting -> Color? in
            guard meeting.status == .confirmed,
                  Calendar.current.component(.day, from: meeting.focusDate) == day else {
                return nil
            }
            return meeting.iconTint
        }

        if !confirmedColors.isEmpty {
            return confirmedColors
        }

        let hasCoordination = meetings.contains { meeting in
            guard meeting.status != .confirmed else { return false }
            let startDay = Calendar.current.component(.day, from: meeting.candidateStartDate)
            let endDay = Calendar.current.component(.day, from: meeting.candidateEndDate)
            return (startDay...endDay).contains(day)
        }

        return hasCoordination ? [Color(uiColor: .systemOrange)] : []
    }
}

struct HomeCoordinationOverviewCard: View {
    let meetings: [HomeMeeting]
    let onSelect: (() -> Void)?

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("조율 중")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(meetings.count)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("건")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)

                Spacer(minLength: 8)

                Text(summaryText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.bottomBentoHeight, maxHeight: HomeGridMetrics.bottomBentoHeight, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }

    private var summaryText: String {
        guard !meetings.isEmpty else { return "진행 중인 조율 없음" }
        return meetings.prefix(2).map(\.shortHomeTitle).joined(separator: " · ")
    }
}

struct HomeCompactCreateCard: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .systemBlue).opacity(0.1), in: Circle())

                Spacer(minLength: 10)

                Text("새 회의 조율")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("후보 기간부터 설정")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.bottomBentoHeight, maxHeight: HomeGridMetrics.bottomBentoHeight, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}

struct HomeCreateMeetingTile: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("새 조율")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                        .padding(.horizontal, 10)
                        .frame(height: 27)
                        .background(Color(uiColor: .systemBlue).opacity(0.1), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("모두가 가능한 시간을 찾아보세요")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("후보 기간과 참석자를 정하면 팀원들의 응답을 한곳에서 비교할 수 있어요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)

                Spacer(minLength: 14)

                Text("새 회의 만들기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.primaryHeight, maxHeight: HomeGridMetrics.primaryHeight, alignment: .leading)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}


struct HomeNextActionTile: View {
    let meeting: HomeMeeting
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(meeting.homeActionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(meeting.iconTint)
                        .padding(.horizontal, 10)
                        .frame(height: 27)
                        .background(meeting.iconTint.opacity(0.1), in: Capsule())

                    Spacer(minLength: 8)

                    Text("\(meeting.respondedCount)/\(meeting.memberCount) 응답")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(meeting.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(meeting.dateRange) · 1시간 · \(meeting.memberCount)명")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 14)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    ProgressView(value: responseProgress)
                        .tint(meeting.iconTint)

                    Text("\(Int(responseProgress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(meeting.homeActionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(.top, 14)
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.featureHeight, alignment: .topLeading)
            .background {
                HomeGridMetrics.cardShape
                    .fill(Color(uiColor: .systemBackground))
                    .overlay {
                        HomeGridMetrics.cardShape
                            .fill(meeting.iconTint.opacity(0.035))
                    }
            }
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }

    private var responseProgress: Double {
        guard meeting.memberCount > 0 else { return 0 }
        return min(max(Double(meeting.respondedCount) / Double(meeting.memberCount), 0), 1)
    }
}

struct HomeConfirmedMeetingTile: View {
    let meeting: HomeMeeting
    var isNewlyConfirmed = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("다가오는 회의", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGreen))

                    Spacer(minLength: 8)

                    Text(isNewlyConfirmed ? "새로 확정" : "확정")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGreen))
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(Color(uiColor: .systemGreen).opacity(0.11), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(meeting.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(homeDateText) · \(meeting.timeRange)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Label(meeting.homePlaceText, systemImage: "location.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 15)

                Spacer(minLength: 12)

                HStack {
                    AvatarStack(
                        names: meeting.memberInitials,
                        maxVisible: 4,
                        size: 28,
                        borderColor: Color(uiColor: .systemBackground),
                        borderWidth: 2,
                        overlap: 8
                    )

                    Text("\(meeting.memberCount)명 참석")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.confirmedHeight, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }

    private var homeDateText: String {
        "\(Calendar.current.component(.month, from: meeting.focusDate))월 \(meeting.confirmedDay)일 \(meeting.confirmedWeekday)요일"
    }
}

struct HomeQuickCreateRow: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 34, height: 34)
                    .background(Color(uiColor: .systemBlue).opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("새 회의 조율")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("후보 기간과 참석자 설정")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.commandHeight, maxHeight: HomeGridMetrics.commandHeight)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}

struct HomePendingResponseRow: View {
    let meeting: HomeMeeting

    var body: some View {
        HStack(spacing: 12) {
            AvatarStack(
                names: pendingNames,
                maxVisible: 2,
                size: 30,
                borderColor: Color(uiColor: .systemBackground),
                borderWidth: 2,
                overlap: 8
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("응답 대기 \(meeting.remainingCount)명")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("아직 시간을 입력하지 않았어요")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("다시 요청") {
                print("Remind pending members")
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Color(uiColor: .systemBlue))
        }
        .padding(.horizontal, HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.pendingHeight, maxHeight: HomeGridMetrics.pendingHeight)
        .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
    }

    private var pendingNames: [String] {
        let count = min(meeting.remainingCount, meeting.memberInitials.count)
        return Array(meeting.memberInitials.suffix(count))
    }
}

struct HomeScheduledMeetingListTile: View {
    let meetings: [HomeMeeting]
    let newlyConfirmedMeetingID: String?
    let onSelectMeeting: (HomeMeeting) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("이후 일정")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(meetings.count)건")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.bottom, 8)

            Divider()

            ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                Button {
                    onSelectMeeting(meeting)
                } label: {
                    HStack(spacing: 12) {
                        VStack(spacing: 1) {
                            Text(meeting.confirmedWeekday)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(meeting.confirmedDay)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        }
                        .frame(width: 34)

                        Rectangle()
                            .fill(meeting.iconTint)
                            .frame(width: 3, height: 34)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(meeting.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if meeting.id == newlyConfirmedMeetingID {
                                    Text("새로 확정")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color(uiColor: .systemGreen))
                                        .padding(.horizontal, 6)
                                        .frame(height: 18)
                                        .background(
                                            Color(uiColor: .systemGreen).opacity(0.1),
                                            in: Capsule()
                                        )
                                        .fixedSize()
                                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                                }
                            }

                            Text("\(meeting.timeRange) · \(meeting.homePlaceText)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < meetings.count - 1 {
                    Divider()
                        .padding(.leading, 49)
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
    }
}

struct HomeResponseRequestCard: View {
    let meeting: HomeMeeting
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemOrange))
                    .frame(width: 38, height: 38)
                    .background(Color(uiColor: .systemOrange).opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("내 응답 필요")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemOrange))

                    Text(meeting.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(meeting.dateRange) · \(meeting.respondedCount)/\(meeting.memberCount) 응답")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Text("시간 입력")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(.horizontal, HomeGridMetrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HomeGridMetrics.responseRequestHeight, maxHeight: HomeGridMetrics.responseRequestHeight)
            .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
            .contentShape(HomeGridMetrics.cardShape)
        }
        .buttonStyle(.plain)
    }
}

struct HomeActiveMeetingListTile: View {
    let meetings: [HomeMeeting]
    let selectedMeetingID: String?
    let onSelectMeeting: (HomeMeeting) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("진행 중인 조율")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(meetings.count)건")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                Button {
                    onSelectMeeting(meeting)
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: meeting.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(meeting.iconTint)
                            .frame(width: 32, height: 32)
                            .background(meeting.iconTint.opacity(0.1), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(meeting.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(meeting.homeActionTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    meeting.id == selectedMeetingID ? Color(uiColor: .secondarySystemBackground) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if index < meetings.count - 1 {
                    Divider()
                        .padding(.leading, 43)
                }
            }
        }
        .padding(HomeGridMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: HomeGridMetrics.cardShape)
    }
}

extension HomeMeeting {
    var homeActionTitle: String {
        switch stage {
        case .hostAvailability:
            return "내 가능 시간 입력"
        case .collectingResponses:
            return "팀원 응답 확인"
        case .bracketReview:
            return "회의 시간 도출"
        case .confirmed:
            return "확정 일정 확인"
        }
    }

    var homeActionDetail: String {
        switch stage {
        case .hostAvailability:
            return "후보 기간에서 가능·부담·불가 시간을 입력해주세요."
        case .collectingResponses:
            return "\(respondedCount)/\(memberCount)명 응답을 캘린더에서 확인할 수 있어요."
        case .bracketReview:
            return "모든 응답을 비교해 가장 안정적인 시간을 확인하세요."
        case .confirmed:
            return "확정된 일정이 캘린더에 반영되었습니다."
        }
    }

    var homePlaceText: String {
        let components = subtitle
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let modeIndex = components.firstIndex(where: { $0 == "온라인" || $0 == "오프라인" }) else {
            return sectionName
        }

        if components[modeIndex] == "온라인" {
            return "온라인"
        }

        let locationIndex = components.index(after: modeIndex)
        return locationIndex < components.endIndex ? components[locationIndex] : "오프라인"
    }
}

struct StatusPill: View {
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

struct ResponseProgressView: View {
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

enum ProfileAsset {
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

struct ProfileAvatar: View {
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

struct AvatarStack: View {
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

struct HomeMeeting: Identifiable {
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

    var isInvitation: Bool {
        id.hasPrefix("invited-")
    }

    var isPrototypeSeed: Bool {
        id.hasPrefix("existing-") || id.hasPrefix("hosted-") || id.hasPrefix("invited-")
    }

    var shortHomeTitle: String {
        if title.contains("신규 기능") { return "스펙 리뷰" }
        if title.contains("킥오프") { return "킥오프 회의" }
        return title
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

    static let existingMeetings = [
        HomeMeeting(
            id: "existing-brand-system-review",
            title: "브랜드 시스템 리뷰",
            sectionName: "디자인팀",
            iconName: "paintpalette.fill",
            subtitle: "디자인팀 · 컴포넌트 가이드 점검 · 오프라인 · 디자인팀 회의실",
            dateRange: "7월 15일",
            timeRange: "11:00 - 12:00",
            excludedTimeRule: .none,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 5,
            respondedCount: 5,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: ["나", "이서연", "오유진", "송승아", "한유나"],
            requiredMemberIndexes: [0, 1, 2, 3],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 15),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 15),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 15),
            confirmedDay: "15",
            confirmedWeekday: "수"
        ),
        HomeMeeting(
            id: "existing-product-sprint-review",
            title: "제품 스프린트 리뷰",
            sectionName: "제품팀",
            iconName: "checklist",
            subtitle: "제품팀 · 다음 스프린트 범위 점검 · 오프라인 · 프로젝트룸 A",
            dateRange: "7월 16일",
            timeRange: "15:00 - 16:00",
            excludedTimeRule: .none,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 6,
            respondedCount: 6,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: ["나", "김민준", "문준호", "박도윤", "최하린", "윤재현"],
            requiredMemberIndexes: [0, 1, 2, 3],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 16),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 16),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 16),
            confirmedDay: "16",
            confirmedWeekday: "목"
        ),
        HomeMeeting(
            id: "existing-interview-share",
            title: "사용자 인터뷰 공유",
            sectionName: "리서치",
            iconName: "bubble.left.and.bubble.right.fill",
            subtitle: "리서치 · 핵심 인사이트 공유 · 온라인",
            dateRange: "7월 17일",
            timeRange: "10:00 - 11:00",
            excludedTimeRule: .none,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 4,
            respondedCount: 4,
            status: .confirmed,
            stage: .confirmed,
            memberInitials: ["나", "정지우", "임다혜", "김민준"],
            requiredMemberIndexes: [0, 1, 2],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 17),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 17),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 17),
            confirmedDay: "17",
            confirmedWeekday: "금"
        ),
        HomeMeeting(
            id: "hosted-quarterly-kickoff",
            title: "3분기 킥오프 회의",
            sectionName: "제품팀",
            iconName: "flag.fill",
            subtitle: "제품팀 · 3분기 목표와 역할 정리 · 오프라인 · 타운홀 B",
            dateRange: "7월 14일 - 18일",
            timeRange: "09:00 - 18:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 6,
            respondedCount: 4,
            status: .collecting,
            stage: .collectingResponses,
            memberInitials: ["나", "김민준", "이서연", "박도윤", "정지우", "임다혜"],
            requiredMemberIndexes: [0, 1, 2, 3],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 14),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 18),
            confirmedDay: "14",
            confirmedWeekday: "화"
        ),
        HomeMeeting(
            id: "invited-feature-spec-review",
            title: "신규 기능 스펙 리뷰",
            sectionName: "제품팀",
            iconName: "checklist",
            subtitle: "제품팀 · 신규 기능 범위 검토 · 오프라인 · 프로젝트룸 B",
            dateRange: "7월 21일 - 25일",
            timeRange: "09:00 - 18:00",
            excludedTimeRule: .lunch,
            derivationCriteria: .default,
            hostAvailabilityEntries: [:],
            memberCount: 6,
            respondedCount: 2,
            status: .waiting,
            stage: .hostAvailability,
            memberInitials: ["나", "김민준", "문준호", "박도윤", "정지우", "임다혜"],
            requiredMemberIndexes: [0, 1, 2, 3],
            focusDate: Self.makeDate(year: 2026, month: 7, day: 21),
            candidateStartDate: Self.makeDate(year: 2026, month: 7, day: 21),
            candidateEndDate: Self.makeDate(year: 2026, month: 7, day: 25),
            confirmedDay: "21",
            confirmedWeekday: "화"
        )
    ]

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

enum MeetingStage: Equatable {
    case hostAvailability
    case collectingResponses
    case bracketReview
    case confirmed
}

enum MeetingStatus: Equatable {
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
