import SwiftUI

/// SwiftUI view displayed inside the overlay panel.
/// Shows recording status indicator and streaming transcription text with auto-scroll.
struct OverlayView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: status + shortcut hint
            HStack {
                // Recording indicator (pulsing red dot)
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(appState.recordingIndicatorOpacity)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: appState.recordingIndicatorOpacity
                    )
                
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
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
            
            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            
            // Transcription text area with scroll
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        if appState.currentTranscription.isEmpty {
                            Text("話してください...")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(appState.currentTranscription)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Invisible anchor at the bottom for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .onChange(of: appState.currentTranscription) { _ in
                    // Auto-scroll to bottom when text changes
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 520, height: 200)
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
