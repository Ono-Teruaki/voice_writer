@preconcurrency import WhisperKit
import Foundation

/// Manages WhisperKit initialization and transcription.
/// Uses the large-v3-turbo model for optimal speed/accuracy balance.
/// Configured for high-accuracy Japanese transcription with punctuation.
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
        
        // Initial prompt: punctuated natural Japanese to guide Whisper's output style.
        // Whisper mimics the style of the prompt, so using properly punctuated sentences
        // encourages it to output punctuation in the transcription.
        let promptText = """
        最近、生成AIやクラウドコンピューティングといった先端技術が急速に普及しています。\
        特に、分散システムやアルゴリズムの効率化は重要な課題です。\
        RustやPythonなどのプログラミング言語を用いて、スケーラブルなアプリケーションを構築する際には、\
        メモリ管理や非同期処理の深い理解が求められます。
        """
        
        let options = DecodingOptions(
            verbose: false,
            language: "ja",
            temperature: 0.0,
            temperatureFallbackCount: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
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
    
    /// Clean up Whisper artifacts and ensure proper Japanese punctuation
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
        
        // Apply rule-based punctuation if Whisper didn't add enough
        result = ensurePunctuation(result)
        
        // Clean up extra whitespace
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return result
    }
    
    // MARK: - Rule-Based Punctuation
    
    /// Ensure proper Japanese punctuation using rule-based heuristics.
    /// Only adds punctuation where it's clearly missing.
    private func ensurePunctuation(_ text: String) -> String {
        var result = text
        
        // 1. Add 。 after sentence-ending patterns if not already present
        //    Patterns: です, ます, でした, ました, ません, でしょう, だ, た (at end of sentence)
        let sentenceEndPatterns = [
            ("です(?![。、。])", "です。"),
            ("ます(?![。、。])", "ます。"),
            ("でした(?![。、。])", "でした。"),
            ("ました(?![。、。])", "ました。"),
            ("ません(?![。、。])", "ません。"),
            ("でしょう(?![。、。])", "でしょう。"),
        ]
        
        for (pattern, replacement) in sentenceEndPatterns {
            // Only add 。 when followed by a new sentence start (capital letter, kanji, hiragana start)
            // or at the very end of the text
            let regexPattern = pattern + "(?=[\\p{Han}\\p{Katakana}A-Z\"]|$)"
            if let regex = try? NSRegularExpression(pattern: regexPattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        
        // 2. Add 、 before conjunctions/adverbs if missing
        let conjunctions = [
            "しかし", "また", "さらに", "特に", "例えば",
            "一方", "ただし", "なお", "つまり", "そのため",
            "それでは", "したがって", "ところが", "けれども"
        ]
        
        for conj in conjunctions {
            // Add 、 after the conjunction if it follows a sentence boundary or is at text start
            // pattern: (。|^)(conjunction) → ensure 、 after conjunction
            let afterPattern = conj + "(?![、,])"
            let afterReplacement = conj + "、"
            if let _ = try? NSRegularExpression(pattern: afterPattern) {
                // Only replace when conjunction appears after 。 or at start of a clause
                let checkAfter = "(?<=。)" + afterPattern
                if let regexAfterPeriod = try? NSRegularExpression(pattern: checkAfter) {
                    result = regexAfterPeriod.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: afterReplacement
                    )
                }
            }
        }
        
        // 3. Remove duplicate punctuation
        result = result.replacingOccurrences(of: "。。", with: "。")
        result = result.replacingOccurrences(of: "、、", with: "、")
        result = result.replacingOccurrences(of: "。、", with: "。")
        
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
