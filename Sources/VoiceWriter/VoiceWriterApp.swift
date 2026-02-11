import SwiftUI

/// Main entry point for the VoiceWriter macOS application.
/// Runs as a menu bar app (no dock icon) using MenuBarExtra.
@main
struct VoiceWriterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    private var menuBarIcon: String {
        switch appState.state {
        case .idle:
            return "mic.badge.plus"
        case .recording:
            return "mic.fill"
        case .processing:
            return "mic.badge.xmark"
        }
    }
}

/// Menu bar dropdown view
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                }
                
                if !appState.isModelLoaded {
                    Text(appState.modelLoadingProgress)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            Divider()
            
            // Actions
            Button {
                appState.toggleRecording()
            } label: {
                HStack {
                    if appState.state == .recording {
                        Image(systemName: "stop.fill")
                        Text("録音停止")
                    } else {
                        Image(systemName: "mic.fill")
                        Text("録音開始")
                    }
                    Spacer()
                    Text("⌘⌥V")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!appState.isModelLoaded || appState.state == .processing)
            .keyboardShortcut("v", modifiers: [.command, .option])
            
            Divider()
            
            // Settings / Info
            Button("アクセシビリティ権限を確認") {
                TextInputSimulator.promptAccessibilityPermissions()
            }
            
            Divider()
            
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            appState.setup()
        }
    }
    
    private var statusColor: Color {
        if !appState.isModelLoaded {
            return .orange
        }
        switch appState.state {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .orange
        }
    }
    
    private var statusText: String {
        if !appState.isModelLoaded {
            return "モデル読み込み中..."
        }
        switch appState.state {
        case .idle: return "待機中 — ⌘⌥V で開始"
        case .recording: return "録音中..."
        case .processing: return "処理中..."
        }
    }
}
