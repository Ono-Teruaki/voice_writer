import SwiftUI
import Combine

/// Central state manager for the VoiceWriter application.
/// Coordinates AudioRecorder, WhisperTranscriber, OverlayPanel, and TextInputSimulator.
@MainActor
final class AppState: ObservableObject {
    
    enum RecordingState {
        case idle
        case recording
        case processing
    }
    
    // MARK: - Published State
    @Published var state: RecordingState = .idle
    @Published var currentTranscription: String = ""
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadingProgress: String = "初期化中..."
    @Published var recordingIndicatorOpacity: Double = 1.0
    @Published var errorMessage: String? = nil
    
    // MARK: - Components
    let audioRecorder = AudioRecorder()
    let transcriber = WhisperTranscriber()
    let hotkeyManager = HotkeyManager()
    let textInputSimulator = TextInputSimulator()
    
    // MARK: - UI
    private var overlayPanel: OverlayPanel?
    
    /// Flag to prevent concurrent transcription requests
    private var isStreamTranscribing = false
    
    // MARK: - Initialization
    
    func setup() {
        // Setup hotkey
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
        hotkeyManager.register()
        
        // Setup audio recorder streaming callback
        audioRecorder.onBufferReady = { [weak self] buffer in
            Task { @MainActor in
                await self?.handleStreamingBuffer(buffer)
            }
        }
        
        // Create overlay panel
        let panel = OverlayPanel()
        panel.setOverlayContent(OverlayView(appState: self))
        self.overlayPanel = panel
        
        // Load Whisper model
        Task {
            do {
                self.modelLoadingProgress = "Whisperモデルを読み込み中..."
                try await transcriber.loadModel()
                self.isModelLoaded = true
                self.modelLoadingProgress = "準備完了"
            } catch {
                self.errorMessage = "モデル読み込みエラー: \(error.localizedDescription)"
                self.modelLoadingProgress = "エラー"
            }
        }
        
        // Check and prompt accessibility permissions
        if !TextInputSimulator.checkAccessibilityPermissions() {
            TextInputSimulator.promptAccessibilityPermissions()
        }
    }
    
    // MARK: - Toggle Recording
    
    func toggleRecording() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            // Ignore if already processing
            break
        }
    }
    
    // MARK: - Recording Control
    
    private func startRecording() {
        guard isModelLoaded else {
            errorMessage = "モデルがまだ読み込まれていません。しばらくお待ちください。"
            return
        }
        
        do {
            currentTranscription = ""
            state = .recording
            recordingIndicatorOpacity = 0.3 // Trigger pulsing animation
            
            // Show overlay
            overlayPanel?.setOverlayContent(OverlayView(appState: self))
            overlayPanel?.positionAtTopCenter()
            overlayPanel?.showPanel()
            
            try audioRecorder.startRecording()
        } catch {
            state = .idle
            errorMessage = "録音エラー: \(error.localizedDescription)"
            overlayPanel?.hidePanel()
        }
    }
    
    private func stopRecording() {
        state = .processing
        
        // Stop recording and get the final buffer
        let finalBuffer = audioRecorder.stopRecording()
        
        Task {
            // Use the streaming transcription result if available,
            // otherwise do a quick final transcription
            var finalText = self.currentTranscription
            
            if finalText.isEmpty && !finalBuffer.isEmpty {
                // No streaming result yet — do one transcription
                do {
                    finalText = try await transcriber.transcribe(audioBuffer: finalBuffer)
                } catch {
                    self.errorMessage = "認識エラー: \(error.localizedDescription)"
                }
            } else if !finalBuffer.isEmpty {
                // We have a streaming result, but check if there's newer audio
                // since the last streaming update. Do a quick final pass.
                do {
                    finalText = try await transcriber.transcribe(audioBuffer: finalBuffer)
                } catch {
                    // Fall back to the streaming result on error
                    print("[VoiceWriter] Final transcription failed, using streaming result")
                }
            }
            
            // Post-process to remove hallucinations
            finalText = transcriber.postProcess(finalText)
            self.currentTranscription = finalText
            
            // Hide overlay
            self.overlayPanel?.hidePanel()
            
            print("[VoiceWriter] Transcription complete: \(finalText.prefix(80))...")
            
            // Input text to active application
            if !finalText.isEmpty {
                // Wait for overlay to fully hide and focus returns to previous app
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
                
                // Run text input on a background thread to avoid blocking main actor
                let simulator = self.textInputSimulator
                let textToInput = finalText
                DispatchQueue.global(qos: .userInitiated).async {
                    print("[VoiceWriter] Pasting text to active app...")
                    simulator.inputText(textToInput)
                    print("[VoiceWriter] Paste completed")
                }
            }
            
            self.state = .idle
            self.recordingIndicatorOpacity = 1.0
        }
    }
    
    // MARK: - Streaming Transcription
    
    private func handleStreamingBuffer(_ buffer: [Float]) async {
        // Prevent concurrent streaming transcription
        guard !isStreamTranscribing else { return }
        guard state == .recording else { return }
        
        isStreamTranscribing = true
        defer { isStreamTranscribing = false }
        
        do {
            let text = try await transcriber.transcribe(audioBuffer: buffer)
            if state == .recording { // Check we're still recording
                self.currentTranscription = text
                // Refresh overlay view
                self.overlayPanel?.setOverlayContent(OverlayView(appState: self))
            }
        } catch {
            // Streaming errors are non-fatal; just log
            print("Streaming transcription error: \(error)")
        }
    }
}
