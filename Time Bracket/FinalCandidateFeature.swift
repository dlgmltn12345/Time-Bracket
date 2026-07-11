import SwiftUI
import UIKit

enum BorderBeamSize {
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

enum BorderBeamColorVariant {
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

enum BorderBeamTheme {
    case dark
    case light
    case auto
}

struct BorderBeamThemePreset {
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

struct BorderBeamModifier: ViewModifier {
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

extension View {
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


struct FinalCandidateComparisonView: View {
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

struct MeetingConfirmationSuccessView: View {
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

struct AnimatedConfirmationCheckmark: View {
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

struct ConfirmationCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.82))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.18))
        return path
    }
}

struct CelebrationConfettiView: UIViewRepresentable {
    let trigger: Int
    let isEnabled: Bool

    func makeUIView(context: Context) -> CelebrationConfettiCanvas {
        CelebrationConfettiCanvas()
    }

    func updateUIView(_ uiView: CelebrationConfettiCanvas, context: Context) {
        uiView.setEmissionToken(isEnabled ? trigger : 0)
    }
}

final class CelebrationConfettiCanvas: UIView {
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

struct DeterministicConfettiRandom {
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

struct FinalCandidateDetailCard: View {
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

struct FinalCandidateInsightPillRow: View {
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

struct FinalCandidateSummaryPill: View {
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

struct FinalCandidateDetailSheet: View {
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

struct FinalCandidateAttendeeRowModel {
    let name: String
    let status: String
    let tint: Color
    let isRequired: Bool
}

struct FinalBurdenCategoryPillRow: View {
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

struct FinalCandidateReasonRow: View {
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
