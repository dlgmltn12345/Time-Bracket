import SwiftUI
import UIKit

struct ResponseCollectionScreen: View {
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

struct BracketReviewScreen: View {
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

enum MeetingDerivationPhase: Int {
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

struct DerivationPhaseChip: Identifiable {
    let title: String
    let symbolName: String
    let color: Color
    var style: DerivationPhaseChipStyle = .semantic

    var id: String {
        "\(title)-\(symbolName)"
    }
}

enum DerivationPhaseChipStyle {
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

struct DerivationPhaseChipRow: View {
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

struct DerivationPhaseChipView: View {
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

struct RecommendationProcessingView: View {
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

struct FinalDerivationCandidate: Identifiable {
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

struct FinalCandidateInsight: Identifiable, Equatable {
    let title: String
    let symbolName: String
    let color: Color
    var detail: String? = nil

    var id: String {
        title
    }
}

struct FinalCandidateRankProfile: Equatable {
    let optionalUnavailableCount: Int
    let burdenCount: Int
    let weightedBurdenScore: Int
    let requiredBurdenCount: Int
    let adjacentStableSlotCount: Int
    let preferencePenalty: Int
}

struct CandidateSelectionRationale {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
}

struct CandidateSelectionStage: Identifiable {
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
