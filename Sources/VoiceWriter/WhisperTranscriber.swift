@preconcurrency import WhisperKit
import Foundation

/// Manages WhisperKit initialization and transcription.
/// Supports both streaming (periodic) and final transcription.
/// Configured for high-accuracy Japanese transcription with large-v3 model.
final class WhisperTranscriber: ObservableObject {
    private var whisperKit: WhisperKit?
    
    @Published var isModelLoaded = false
    @Published var isTranscribing = false
    @Published var modelLoadingProgress: String = "モデルを読み込み中..."
    
    // MARK: - Initial Prompt
    
    /// Initial prompt to guide Whisper's vocabulary and style for Japanese technical content.
    /// This significantly improves recognition of technical terms, proper nouns, and domain-specific vocabulary.
    private let initialPromptText: String = """
    生成AI、クラウドコンピューティング、アルゴリズム、プロセッサ、メモリ管理、非同期処理、\
    Rust、Python、JavaScript、TypeScript、Swift、Docker、Kubernetes、\
    アプリケーション、スケーラブル、データベース、フレームワーク、API、\
    分散システム、機械学習、ディープラーニング、ニューラルネットワーク、\
    プロジェクト、コミュニケーション、マネジメント、エンジニアリング、\
    アーキテクチャ、インフラストラクチャ、デプロイメント、CI/CD、\
    GitHub、AWS、Azure、Google Cloud、OpenAI、\
    持続可能、社会、技術者、研究開発、日常生活
    """
    
    // MARK: - Model Loading
    
    /// Initialize WhisperKit with the large-v3 model for maximum Japanese accuracy.
    /// Downloads the model on first launch if not cached (~1.5GB).
    func loadModel() async throws {
        DispatchQueue.main.async {
            self.modelLoadingProgress = "Whisper large-v3 モデルをダウンロード中...\n(初回は約1.5GBのダウンロードが必要です)"
        }
        
        let config = WhisperKitConfig(
            model: "large-v3",
            verbose: false,
            prewarm: true
        )
        
        let kit = try await WhisperKit(config)
        
        DispatchQueue.main.async {
            self.whisperKit = kit
            self.isModelLoaded = true
            self.modelLoadingProgress = "モデル準備完了 (large-v3)"
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio buffer for streaming display (faster, less accurate).
    /// Uses simpler options for speed during real-time display.
    func transcribeStreaming(audioBuffer: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }
        guard !audioBuffer.isEmpty else { return "" }
        
        let options = DecodingOptions(
            verbose: false,
            language: "ja",
            temperature: 0.0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            suppressBlank: true,
            compressionRatioThreshold: nil,
            logProbThreshold: nil,
            noSpeechThreshold: nil
        )
        
        let result = try await whisperKit.transcribe(
            audioArray: audioBuffer,
            decodeOptions: options
        )
        
        let text = result.map { $0.text }.joined(separator: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return text
    }
    
    /// Transcribe audio buffer for final output (full accuracy).
    /// Uses VAD chunking and all accuracy-enhancing options.
    func transcribeFinal(audioBuffer: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }
        guard !audioBuffer.isEmpty else { return "" }
        
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
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            suppressBlank: true,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            noSpeechThreshold: 0.6,
            chunkingStrategy: .vad
        )
        
        let result = try await whisperKit.transcribe(
            audioArray: audioBuffer,
            decodeOptions: options
        )
        
        // Combine all segments, filter out empty/hallucinated segments
        let text = result.map { $0.text }
            .joined(separator: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Post-process: remove common Whisper hallucination artifacts
        let cleaned = postProcess(text)
        return cleaned
    }
    
    // MARK: - Post-Processing
    
    /// Clean up common Whisper artifacts and hallucinations
    private func postProcess(_ text: String) -> String {
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
