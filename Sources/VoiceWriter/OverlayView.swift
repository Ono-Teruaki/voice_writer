import SwiftUI

/// SwiftUI view displayed inside the overlay panel.
/// Shows recording status indicator and streaming transcription text.
struct OverlayView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator (pulsing red dot)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(appState.recordingIndicatorOpacity)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: appState.recordingIndicatorOpacity
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Status label
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Transcription text
                if appState.currentTranscription.isEmpty {
                    Text("話してください...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(appState.currentTranscription)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            // Keyboard shortcut hint
            Text("⌘⌥V で確定")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(minWidth: 400, maxWidth: 500)
        .background(
            VisualEffectBlur()
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }
    
    private var statusText: String {
        switch appState.state {
        case .recording:
            return "🎤 録音中"
        case .processing:
            return "⏳ 処理中..."
        default:
            return ""
        }
    }
}

/// NSVisualEffectView wrapper for SwiftUI to create a blur background
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
