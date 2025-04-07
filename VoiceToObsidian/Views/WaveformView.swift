import SwiftUI

struct WaveformView: View {
    var isRecording: Bool
    var color: Color
    
    // Animation properties
    @State private var phase: CGFloat = 0
    @State private var amplitude: CGFloat = 1.0
    
    // Timer for animation
    @State private var timer: Timer?
    
    // Number of bars in the waveform
    private let barCount = 9
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.flexokiBackground2)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Waveform visualization
                HStack(spacing: geometry.size.width / CGFloat(barCount * 3)) {
                    ForEach(0..<barCount, id: \.self) { index in
                        WaveformBar(
                            index: index,
                            barCount: barCount,
                            phase: phase,
                            amplitude: amplitude,
                            isRecording: isRecording,
                            size: geometry.size
                        )
                        .fill(color)
                    }
                }
                .frame(width: geometry.size.width * 0.7)
                
                // Dots between bars
                HStack(spacing: geometry.size.width / CGFloat(barCount * 3)) {
                    ForEach(0..<(barCount - 1), id: \.self) { index in
                        Circle()
                            .fill(color.opacity(isRecording ? 0.8 : 0.5))
                            .frame(width: 4, height: 4)
                            .offset(x: geometry.size.width / CGFloat(barCount * 2))
                    }
                }
                .frame(width: geometry.size.width * 0.7)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            startAnimationIfNeeded()
        }
        .onChange(of: isRecording) { newValue in
            startAnimationIfNeeded()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startAnimationIfNeeded() {
        timer?.invalidate()
        
        if isRecording {
            // Create a repeating timer that updates the phase
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    phase += 0.05
                    amplitude = 0.7 + 0.3 * sin(phase * 2)
                }
            }
        } else {
            // Reset animation state when not recording
            withAnimation(.easeOut(duration: 0.3)) {
                phase = 0
                amplitude = 1.0
            }
        }
    }
}

struct WaveformBar: Shape {
    let index: Int
    let barCount: Int
    let phase: CGFloat
    let amplitude: CGFloat
    let isRecording: Bool
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Calculate the height of this bar
        let normalizedIndex = CGFloat(index) / CGFloat(barCount - 1) // 0 to 1
        let centerIndex = CGFloat(barCount - 1) / 2
        let distanceFromCenter = abs(CGFloat(index) - centerIndex) / centerIndex // 0 at center, 1 at edges
        
        // Create a symmetrical pattern with tallest bars in the center
        let baseHeight = (1.0 - distanceFromCenter) * rect.height * 0.8
        
        // Add animation when recording
        var barHeight = baseHeight
        if isRecording {
            // Add wave-like animation based on position and phase
            let wavePhase = phase + CGFloat(index) * 0.3
            barHeight = baseHeight * (0.7 + 0.3 * sin(wavePhase * 5))
            
            // Add some randomness for a more natural look
            let randomFactor = 1.0 + 0.1 * sin(wavePhase * 11)
            barHeight *= randomFactor
        }
        
        // Ensure height is within bounds
        barHeight = min(max(barHeight, rect.height * 0.1), rect.height * 0.9)
        
        // Calculate bar width (thinner for a more elegant look)
        let barWidth = rect.width * 0.6
        
        // Position the bar
        let x = (rect.width - barWidth) / 2
        let y = (rect.height - barHeight) / 2
        
        // Create the bar
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: barWidth, height: barHeight),
            cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
        )
        
        return path
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(isRecording: true, color: .flexokiAccentBlue)
            .frame(width: 250, height: 250)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.flexokiBackground)
        
        WaveformView(isRecording: false, color: .flexokiAccentBlue)
            .frame(width: 250, height: 250)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.flexokiBackground)
    }
}
