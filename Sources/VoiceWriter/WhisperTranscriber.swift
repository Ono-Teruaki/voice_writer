import WhisperKit
import Foundation

/// Manages WhisperKit initialization and transcription.
/// Supports both streaming (periodic) and final transcription.
final class WhisperTranscriber: ObservableObject {
    private var whisperKit: WhisperKit?
    
    @Published var isModelLoaded = false
    @Published var isTranscribing = false
    @Published var modelLoadingProgress: String = "モデルを読み込み中..."
    
    /// Initialize WhisperKit with the specified model.
    /// Downloads the model on first launch if not cached.
    func loadModel() async throws {
        DispatchQueue.main.async {
            self.modelLoadingProgress = "Whisperモデルをダウンロード中..."
        }
        
        let config = WhisperKitConfig(
            model: "base",
            verbose: false,
            prewarm: true
        )
        
        let kit = try await WhisperKit(config)
        
        DispatchQueue.main.async {
            self.whisperKit = kit
            self.isModelLoaded = true
            self.modelLoadingProgress = "モデル準備完了"
        }
    }
    
    /// Transcribe audio buffer (used for both streaming and final transcription).
    /// - Parameter audioBuffer: Array of Float samples at 16kHz mono
    /// - Returns: Transcribed text string
    func transcribe(audioBuffer: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }
        
        guard !audioBuffer.isEmpty else {
            return ""
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isTranscribing = false
            }
        }
        
        let options = DecodingOptions(
            verbose: false,
            language: "ja",
            temperature: 0.0,
            usePrefillPrompt: true,
            suppressBlank: true
        )
        
        let result = try await whisperKit.transcribe(
            audioArray: audioBuffer,
            decodeOptions: options
        )
        
        // Combine all segments into the full text
        let text = result.map { $0.text }.joined(separator: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return text
    }
    
    enum TranscriberError: LocalizedError {
        case modelNotLoaded
        
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Whisperモデルがまだ読み込まれていません"
            }
        }
    }
}
