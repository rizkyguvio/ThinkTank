import SwiftUI

// MARK: - Onboarding Data

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let symbolEffect: Bool
    let title: String
    let subtitle: String
    let accentLine: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "brain.filled.head.profile",
        symbolEffect: true,
        title: "Your Mind,\nUnfiltered.",
        subtitle: "Think Tank is a place for raw thoughts. No folders. No formatting. Just you and an idea.",
        accentLine: "Capture first. Organize never."
    ),
    OnboardingPage(
        icon: "hand.draw.fill",
        symbolEffect: false,
        title: "Rip It.",
        subtitle: "Type a thought on the paper. Then drag it right — or tap Rip It — to commit it to your Tank.",
        accentLine: "The gesture is the ritual."
    ),
    OnboardingPage(
        icon: "sparkles",
        symbolEffect: true,
        title: "Connections\nFind Themselves.",
        subtitle: "Every idea you capture gets analyzed. Similar thoughts form edges. Clusters reveal your obsessions.",
        accentLine: "Your brain, mapped."
    ),
    OnboardingPage(
        icon: "checkmark.circle.fill",
        symbolEffect: false,
        title: "Swipe to\nResolve.",
        subtitle: "In your Notes, swipe a card right to resolve it. Swipe left to delete. Your ideas have a lifecycle.",
        accentLine: "Ideas evolve. So do you."
    ),
    OnboardingPage(
        icon: "bell.and.time.fill",
        symbolEffect: true,
        title: "Time-Traveling\nThoughts.",
        subtitle: "Write \"tomorrow\" or \"Friday at 5pm\" in a note. Think Tank will naturally detect it and resurface the idea when the time is right.",
        accentLine: "Never forget a spark."
    ),
]

// MARK: - Main Onboarding View

struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Binding var isPresented: Bool

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimatingIn = false
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.92
    @State private var pulseRings = false

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { } // Absorb taps — prevent accidental dismiss

            // Card
            VStack(spacing: 0) {
                pageContent
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(Pastel.primaryText.opacity(0.08))

                bottomBar
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Pastel.background)
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [Pastel.accent.opacity(0.06), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(Pastel.primaryText.opacity(0.08), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            .padding(.horizontal, 20)
            .offset(x: dragOffset)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .gesture(swipeGesture)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                cardOpacity = 1
                cardScale = 1
            }
        }
    }

    // MARK: - Page Content

    private var pageContent: some View {
        let page = pages[currentPage]

        return VStack(alignment: .leading, spacing: 0) {

            // Icon area with ambient glow rings
            ZStack {
                // Pulse rings
                if pulseRings {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .strokeBorder(Pastel.accent.opacity(0.12 - Double(i) * 0.04), lineWidth: 1)
                            .frame(width: CGFloat(80 + i * 28), height: CGFloat(80 + i * 28))
                            .scaleEffect(pulseRings ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 1.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.25),
                                value: pulseRings
                            )
                    }
                }

                Circle()
                    .fill(Pastel.accent.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: page.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Pastel.accent, Pastel.sky],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: currentPage)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .onAppear { pulseRings = true }

            // Text
            VStack(alignment: .leading, spacing: 12) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Pastel.primaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("title-\(currentPage)") // Force re-render on page change
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Text(page.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Pastel.primaryText.opacity(0.55))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("subtitle-\(currentPage)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                // Accent line — the "hook"
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Pastel.accent)
                        .frame(width: 20, height: 1.5)
                    Text(page.accentLine)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(Pastel.accent)
                }
                .padding(.top, 4)
                .id("accent-\(currentPage)")
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: currentPage)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Pastel.accent : Pastel.primaryText.opacity(0.15))
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Don't show again
            Button {
                hasSeenOnboarding = true
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Don't show again")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Pastel.primaryText.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Pastel.primaryText.opacity(0.06))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Next / Get Started
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        currentPage += 1
                    }
                    HapticManager.shared.softTap()
                } else {
                    NotificationEngine.shared.requestAuthorization()
                    dismiss()
                    HapticManager.shared.ripItSuccess()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 14, weight: .bold))
                    if currentPage < pages.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundStyle(Pastel.background)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Capsule().fill(Pastel.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Only allow leftward drag (forward), with resistance going backward
                let x = value.translation.width
                dragOffset = x < 0 ? x * 0.4 : x * 0.15
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragOffset = 0
                }
                if value.translation.width < -threshold && currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        currentPage += 1
                    }
                    HapticManager.shared.softTap()
                } else if value.translation.width > threshold && currentPage > 0 {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        currentPage -= 1
                    }
                    HapticManager.shared.softTap()
                }
            }
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            cardOpacity = 0
            cardScale = 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}
