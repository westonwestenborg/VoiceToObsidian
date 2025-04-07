import SwiftUI

struct WaveformView: View {
    var isRecording: Bool
    var color: Color
    
    // Animation state
    @State private var phase: CGFloat = 0
    private let barCount = 25
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.flexokiBackground2)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Audio bars visualization
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        AudioBar(
                            index: index,
                            barCount: barCount,
                            phase: phase,
                            isRecording: isRecording,
                            color: color,
                            size: geometry.size
                        )
                    }
                }
                .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            // Start a continuous animation using a timer
            let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    phase += 0.05
                }
            }
            // Make sure the timer continues to fire when scrolling
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

struct AudioBar: View {
    let index: Int
    let barCount: Int
    let phase: CGFloat
    let isRecording: Bool
    let color: Color
    let size: CGSize
    
    var body: some View {
        // Calculate animation properties based on position
        let midPoint = Double(barCount) / 2.0
        let distanceFromCenter = abs(Double(index) - midPoint)
        let normalizedDistance = distanceFromCenter / midPoint
        
        // Create a wave effect by adjusting amplitude
        let baseAmplitude = 0.8 - (normalizedDistance * 0.3)
        
        // Calculate the animated height
        let wavePhase = phase + CGFloat(index) * 0.3
        let sineValue = sin(wavePhase * 5)
        
        // Determine animation intensity based on recording state
        let intensity: Double = isRecording ? 1.0 : 0.6
        let heightMultiplier = baseAmplitude * (0.7 + 0.3 * Double(sineValue)) * intensity
        let barHeight = size.height * 0.6 * CGFloat(heightMultiplier)
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4, height: barHeight)
            .frame(height: size.height * 0.6, alignment: .center)
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
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
                
            WaveformView(isRecording: true, color: .flexokiAccentRed)
                .frame(width: 250, height: 250)
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.flexokiBackground)
        }
    }
}
