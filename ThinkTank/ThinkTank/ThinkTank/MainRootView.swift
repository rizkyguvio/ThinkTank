import SwiftUI
import SwiftData

struct MainRootView: View {
    @State private var selectedTab = 0 // Default to Capture
    @State private var tabOpacity: Double = 1.0

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool
    @State private var text: String = ""
    @State private var selectedIdea: Idea?
    @State private var processor: RipItProcessor?
    @StateObject private var refEngine = ReferenceEngine()
    @State private var isRefEngineInitialized = false

    // Ritual State
    @State private var ripProgress: CGFloat = 0
    @State private var isRipping: Bool = false
    @State private var isInteracting: Bool = false
    @State private var bodyOffset: CGSize = .zero
    @State private var bodyRotation: Double = 0
    @State private var bodyRotation3D: Double = 0
    @State private var bodyOpacity: Double = 1.0
    @State private var bodyScale: CGFloat = 1.0
    
    @State private var nextSheetOffset: CGFloat = 1000
    @State private var nextSheetOpacity: Double = 0
    
    @State private var hapticTickCounter: Int = 0

    private var hasContent: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    private let paperHeight: CGFloat = 420
    private let paperHeightFocused: CGFloat = 460

    var body: some View {
        ZStack(alignment: .bottom) {
            Pastel.radialBackground
                .ignoresSafeArea()
                .onTapGesture {
                    isTextFieldFocused = false
                }
            
            // Only render the active tab — NOT using .page style TabView
            // because its UIScrollView steals horizontal swipes from List's .swipeActions.
            // Using switch instead of ZStack-with-opacity to avoid rendering all 3 tabs simultaneously.
            Group {
                switch selectedTab {
                case 0:
                    captureTabView
                case 1:
                    NotesView()
                case 2:
                    AnalyticsView(tabOpacity: $tabOpacity)
                default:
                    captureTabView
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            
            // Floating Tab Bar
            if !isTextFieldFocused && !isRipping {
                CustomTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .opacity(tabOpacity)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Capture Tab

    private var currentPaperHeight: CGFloat {
        isTextFieldFocused ? paperHeightFocused : paperHeight
    }

    private var captureTabView: some View {
        ZStack {
            GeometryReader { proxy in
                let dragWidth = proxy.size.width
                
                VStack(spacing: 0) {
                    // Branding
                    if !isTextFieldFocused {
                        HStack {
                            Text("THINK TANK")
                                .font(.system(size: 14, weight: .black))
                                .kerning(4)
                                .foregroundStyle(Pastel.header.opacity(0.6))
                            Spacer()
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 64)
                        .transition(.opacity)
                    }

                    Spacer(minLength: isTextFieldFocused ? 60 : 30)
                    
                    if !isTextFieldFocused, let obsession = processor?.lastObsessions.first {
                        HStack(spacing: 6) {
                            Circle().fill(Pastel.rose).frame(width: 6, height: 6)
                            Text("Obsession Detected: \(obsession.intent)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Pastel.rose.opacity(0.8))
                        }
                        .padding(.bottom, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ZStack {
                        // 1. Next Sheet (slides in after rip)
                        simpleSheet()
                            .offset(y: nextSheetOffset)
                            .opacity(nextSheetOpacity)
                            .scaleEffect(0.98)
                        
                        // 2. LEFT PAPER: The Spine (stays behind during rip)
                        if ripProgress > 0 {
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Pastel.paper)
                                    .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                                
                                Rectangle()
                                    .fill(Pastel.rose.opacity(0.2))
                                    .frame(width: 1.5)
                                    .padding(.leading, 42)
                            }
                            .frame(height: currentPaperHeight)
                            .padding(.horizontal, 24)
                            .mask(NaturalSideTearMask(progress: ripProgress, inverse: true))
                        }
                        
                        // 3. RIGHT PAPER: The Page (tears away)
                        paperBodyView
                            // Tear mask BEFORE transforms so the jagged edge moves WITH the page
                            .mask {
                                if ripProgress > 0 {
                                    NaturalSideTearMask(progress: ripProgress, inverse: false)
                                } else {
                                    Color.black // Full coverage = show all (rounded from clipShape inside paperBodyView)
                                }
                            }
                            // Fiber overlay at tear point
                            .overlay(alignment: .leading) {
                                if ripProgress > 0 && ripProgress < 1.0 {
                                    FiberLine(progress: ripProgress)
                                        .offset(x: 42 + 24) // 42 tearX + 24 padding
                                }
                            }
                            // Transforms AFTER mask so jagged edge travels with page
                            .offset(bodyOffset)
                            .rotationEffect(.degrees(bodyRotation))
                            .rotation3DEffect(.degrees(bodyRotation3D), axis: (x: 0, y: 1, z: 0))
                            .scaleEffect(bodyScale)
                        
                        // Gesture Layer
                        if !isTextFieldFocused && !isRipping {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { 
                                    withAnimation(.spring()) { isTextFieldFocused = true }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 10)
                                        .onChanged { value in handleManualDrag(value, dragWidth: dragWidth) }
                                        .onEnded { value in handleManualDragEnd(value) }
                                )
                                .frame(height: currentPaperHeight)
                                .padding(.horizontal, 24)
                        }
                    }

                    Spacer(minLength: 16)

                    // Rip It Button - ALWAYS visible, disabled when empty
                    if !isRipping {
                        Button { performAutoRip() } label: {
                            Text("Rip It")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Pastel.accent))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 48)
                        .disabled(!hasContent)
                        .opacity(hasContent ? 1.0 : 0.3)
                    }
                    
                    Spacer(minLength: isTextFieldFocused ? 10 : 120)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(refEngine.suggestions) { idea in
                                Button {
                                    selectedIdea = idea
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text.viewfinder")
                                        Text(idea.content.prefix(20) + "...")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Pastel.accent.opacity(0.1))
                                    .foregroundStyle(Pastel.accent)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    

                }
            }
        }
        .onAppear { 
            if processor == nil { processor = RipItProcessor(container: modelContext.container) } 
            if !isRefEngineInitialized {
                refEngine.setContainer(modelContext.container)
                isRefEngineInitialized = true
            }
        }
        .onChange(of: text) { _, newValue in
            refEngine.findReferences(for: newValue)
        }
        .sheet(item: $selectedIdea) { idea in
            IdeaDetailSheet(idea: idea, connectedIdeas: []) { _ in }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isTextFieldFocused)
    }

    // MARK: - Paper Body (extracted for clarity)

    private var paperBodyView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Pastel.paper)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            
            // Ink lines
            VStack(spacing: 24) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 1)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 10)
            
            // Red Margin Line
            if ripProgress == 0 {
                Rectangle()
                    .fill(Pastel.rose.opacity(0.2))
                    .frame(width: 1.5)
                    .padding(.leading, 42)
            }
            
            TextEditor(text: $text)
                .font(.system(size: 17))
                .foregroundStyle(Color.black.opacity(0.85))
                .scrollContentBackground(.hidden)
                .padding(.leading, 50)
                .padding(.top, 40)
                .padding(.trailing, 20)
                .focused($isTextFieldFocused)
                .opacity(bodyOpacity)
        }
        .frame(height: currentPaperHeight)
        // clipShape BEFORE padding so it clips the actual paper, not the padding
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
    }

    // MARK: - Ritual Logic

    private func handleManualDrag(_ value: DragGesture.Value, dragWidth: CGFloat) {
        guard hasContent, !isRipping, !isTextFieldFocused else { return }
        isInteracting = true
        tabOpacity = 0.4
        
        let dragScale = 0.7
        let rawProgress = max(0, min(1, Double(value.translation.width / (dragWidth * dragScale))))
        
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
            ripProgress = CGFloat(rawProgress)
            bodyOffset.width = CGFloat(rawProgress * 60)
            bodyOffset.height = CGFloat(rawProgress * 15)
            bodyRotation = rawProgress * 8
            bodyRotation3D = rawProgress * 5
        }
        
        if Int(ripProgress * 40) > hapticTickCounter {
            hapticTickCounter = Int(ripProgress * 40)
            HapticManager.shared.dragPulse(intensity: 0.3)
            if hapticTickCounter % 6 == 0 { SoundManager.shared.playTension() }
        }
    }

    private func handleManualDragEnd(_ value: DragGesture.Value) {
        let vel = value.velocity.width
        if ripProgress > 0.6 || vel > 700 {
            commitRipAction(initialVelocity: vel)
        } else {
            HapticManager.shared.cancelRip()
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                ripProgress = 0
                bodyOffset = .zero
                bodyRotation = 0
                bodyRotation3D = 0
                tabOpacity = 1.0
            }
        }
    }

    private func performAutoRip() {
        guard hasContent && !isRipping else { return }
        isTextFieldFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            commitRipAction(initialVelocity: 0)
        }
    }

    private func commitRipAction(initialVelocity: CGFloat) {
        isRipping = true
        tabOpacity = 0.05
        
        processor?.process(content: text, in: modelContext)
        SoundManager.shared.playRipSequence(isManual: initialVelocity > 0)
        HapticManager.shared.ripItSuccess()
        
        // Phase 1: Tear away
        withAnimation(.easeOut(duration: 0.5)) {
            ripProgress = 1.0
            bodyOffset.width = 120
            bodyOffset.height = 60
            bodyRotation = 12
            bodyRotation3D = 10
        }
        
        // Phase 2: Fly away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.interpolatingSpring(stiffness: 60, damping: 12)) {
                bodyOffset.height = 1200
                bodyOffset.width = 400
                bodyRotation = 45
                bodyOpacity = 0
                bodyScale = 0.85
            }
            
            // Phase 3: Next sheet slides in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                nextSheetOffset = 0
                nextSheetOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                resetCapture()
            }
        }
    }

    private func resetCapture() {
        text = ""
        ripProgress = 0
        isRipping = false
        isInteracting = false
        bodyOffset = .zero
        bodyRotation = 0
        bodyRotation3D = 0
        bodyOpacity = 1.0
        bodyScale = 1.0
        nextSheetOffset = 1000
        nextSheetOpacity = 0
        tabOpacity = 1.0
        hapticTickCounter = 0
    }

    private func simpleSheet() -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Pastel.paper)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            
            Rectangle()
                .fill(Pastel.rose.opacity(0.15))
                .frame(width: 1.5)
                .padding(.leading, 42)
        }
        .frame(height: paperHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
    }
}

// MARK: - Tear Mask

struct NaturalSideTearMask: Shape {
    var progress: CGFloat
    var inverse: Bool
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tearX: CGFloat = 42.0
        let corner: CGFloat = 16.0
        
        // Deterministic jagged edge using sine waves (no random = stable animation)
        func jagX(y: CGFloat) -> CGFloat {
            let base = sin(y * 0.4) * 2.5 + cos(y * 0.85) * 1.8
            let detail = sin(y * 2.1) * 1.2 * progress
            return tearX + base + detail
        }
        
        if inverse {
            // LEFT PAPER (Spine) - rounded left corners, jagged right edge
            path.move(to: CGPoint(x: corner, y: 0))
            
            // Top edge to tear line
            path.addLine(to: CGPoint(x: tearX, y: 0))
            
            // Jagged right edge (top to bottom)
            for y in stride(from: CGFloat(0), through: rect.height, by: 2) {
                path.addLine(to: CGPoint(x: jagX(y: y), y: y))
            }
            
            // Bottom edge
            path.addLine(to: CGPoint(x: tearX, y: rect.height))
            path.addLine(to: CGPoint(x: corner, y: rect.height))
            
            // Bottom-left rounded corner
            path.addArc(
                center: CGPoint(x: corner, y: rect.height - corner),
                radius: corner,
                startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
            )
            
            // Left edge
            path.addLine(to: CGPoint(x: 0, y: corner))
            
            // Top-left rounded corner
            path.addArc(
                center: CGPoint(x: corner, y: corner),
                radius: corner,
                startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
            )
            
            path.closeSubpath()
            
        } else {
            // RIGHT PAPER (Page body) - jagged left edge, rounded right corners
            
            // Start at tear line top
            path.move(to: CGPoint(x: tearX, y: 0))
            
            // Top edge to right corner
            path.addLine(to: CGPoint(x: rect.width - corner, y: 0))
            
            // Top-right rounded corner
            path.addArc(
                center: CGPoint(x: rect.width - corner, y: corner),
                radius: corner,
                startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
            )
            
            // Right edge
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - corner))
            
            // Bottom-right rounded corner
            path.addArc(
                center: CGPoint(x: rect.width - corner, y: rect.height - corner),
                radius: corner,
                startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
            )
            
            // Bottom edge back to tear line
            path.addLine(to: CGPoint(x: tearX, y: rect.height))
            
            // Jagged left edge (bottom to top) - same function = interlocking with spine
            for y in stride(from: rect.height, through: 0, by: -2) {
                path.addLine(to: CGPoint(x: jagX(y: y), y: y))
            }
            
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Fiber Line

struct FiberLine: View {
    let progress: CGFloat
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 2)
                .blur(radius: 0.5)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 8)
                .blur(radius: 3)
        }
    }
}

// MARK: - Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var body: some View {
        HStack {
            tabButton(index: 0, icon: "brain")
            Spacer(); tabButton(index: 1, icon: "tray.full")
            Spacer(); tabButton(index: 2, icon: "chart.dots.scatter")
        }
        .padding(.horizontal, 40).padding(.vertical, 15)
        .background(Capsule().fill(.ultraThinMaterial).shadow(color: .black.opacity(0.15), radius: 10, y: 10))
        .padding(.horizontal, 30).padding(.bottom, 20)
    }
    
    private func tabButton(index: Int, icon: String) -> some View {
        let isSelected = selectedTab == index
        let iconName = (isSelected && icon != "chart.dots.scatter") ? "\(icon).fill" : icon
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index }
            HapticManager.shared.softTap()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isSelected ? Pastel.accent : Pastel.primaryText.opacity(0.3))
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .frame(width: 44, height: 44)
        }
    }
}
