@preconcurrency import WhisperKit
import Foundation

/// Manages WhisperKit initialization and transcription.
/// Uses the large-v3-turbo model for optimal speed/accuracy balance.
/// Configured for high-accuracy Japanese transcription.
final class WhisperTranscriber: ObservableObject {
    private var whisperKit: WhisperKit?
    
    @Published var isModelLoaded = false
    @Published var isTranscribing = false
    @Published var modelLoadingProgress: String = "モデルを読み込み中..."
    
    // MARK: - Model Loading
    
    /// Initialize WhisperKit with the large-v3-turbo model.
    /// This is a distilled model that's ~3-4x faster than large-v3 with similar accuracy.
    /// Downloads on first launch (~954MB).
    func loadModel() async throws {
        DispatchQueue.main.async {
            self.modelLoadingProgress = "Whisper large-v3-turbo をダウンロード中...\n(初回は約950MBのダウンロードが必要です)"
        }
        
        let config = WhisperKitConfig(
            model: "openai_whisper-large-v3_turbo",
            verbose: false,
            prewarm: true
        )
        
        let kit = try await WhisperKit(config)
        
        DispatchQueue.main.async {
            self.whisperKit = kit
            self.isModelLoaded = true
            self.modelLoadingProgress = "モデル準備完了 (large-v3-turbo)"
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio buffer — used for both streaming and final transcription.
    /// Optimized for speed with high-quality settings.
    func transcribe(audioBuffer: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }
        guard !audioBuffer.isEmpty else { return "" }
        
        let options = DecodingOptions(
            verbose: false,
            language: "ja",
            temperature: 0.0,
            temperatureFallbackCount: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            suppressBlank: true,
            compressionRatioThreshold: nil,
            logProbThreshold: nil,
            noSpeechThreshold: 0.6
        )
        
        let result = try await whisperKit.transcribe(
            audioArray: audioBuffer,
            decodeOptions: options
        )
        
        let text = result.map { $0.text }.joined(separator: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return text
    }
    
    // MARK: - Post-Processing
    
    /// Clean up common Whisper artifacts and hallucinations
    func postProcess(_ text: String) -> String {
        var result = text
        
        // Remove common hallucinated tags/markers
        let hallucinations = [
            "(スタッフ)", "(字幕)", "(音楽)", "(拍手)", "(笑)",
            "ご視聴ありがとうございました", "チャンネル登録", "お願いします",
            "♪", "【", "】"
        ]
        
        for hallucination in hallucinations {
            result = result.replacingOccurrences(of: hallucination, with: "")
        }
        
        // Clean up extra whitespace
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return result
    }
    
    // MARK: - Errors
    
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
