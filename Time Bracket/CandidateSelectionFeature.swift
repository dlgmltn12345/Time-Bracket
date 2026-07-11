import SwiftUI
import UIKit

struct CandidateSelectionProcessView: View {
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

struct CandidateSelectionStagePage: View {
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

struct CandidateSelectionCountMetric: View {
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

struct CandidateSelectionExcludedRowHeader: View {
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

struct CandidateSelectionSlotRow: View {
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

struct CandidateSelectionDetailMessage: View {
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

struct CandidateSelectionIssue: Identifiable {
    let member: TeamResponseReason
    let title: String
    let symbolName: String
    let tint: Color

    var id: String {
        "\(member.id)-\(title)"
    }
}

struct CandidateSelectionIssueRow: View {
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

struct CandidateSelectionResponseCount: View {
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

struct CandidateSelectionFinalRow: View {
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

struct SequentialDerivationTitle: View {
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

struct OnboardingResponseBlockStage: View {
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

struct OnboardingResponseBlockCard: View, Equatable {
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

struct OnboardingCompactCount: View {
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

struct ResponseCountPill: View {
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

struct DerivationStatusHeader: View {
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

struct DerivationCalendarGhost: View {
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

struct DerivationCandidateStage: View {
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

struct DerivationCandidateCard: View {
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

struct DerivationFinalCandidateCard: View {
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

struct DecisionOverviewCard: View {
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

struct DailyCandidateExtractionCard: View {
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

struct DailyCandidatePill: View {
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

struct DecisionTournamentCard: View {
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

struct FinalMeetingProposalCard: View {
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

struct MeetingDecisionMetric: View {
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

struct MeetingDecisionDayBucket: Identifiable {
    let date: Date
    let candidates: [MeetingDecisionCandidate]

    var id: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }
}

struct MeetingDecisionCandidate: Identifiable, Hashable {
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
