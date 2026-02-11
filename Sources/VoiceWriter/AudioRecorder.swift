import AVFoundation
import Combine
import Accelerate

/// Manages audio recording from the microphone using AVAudioEngine.
/// Captures audio in 16kHz mono Float32 format suitable for Whisper input.
/// Includes audio preprocessing (noise gate, normalization) for improved accuracy.
final class AudioRecorder: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    
    /// Timer for periodic transcription updates
    private var streamingTimer: Timer?
    
    /// Callback invoked periodically with the accumulated audio buffer for streaming transcription
    var onBufferReady: (([Float]) -> Void)?
    
    @Published var isRecording = false
    
    // MARK: - Audio Preprocessing Settings
    
    /// Noise gate threshold: samples below this RMS level are silenced
    private let noiseGateThreshold: Float = 0.005
    
    /// Frame size for noise gate processing (in samples at 16kHz)
    private let noiseGateFrameSize: Int = 1600 // 100ms frames
    
    /// Start recording audio from the default input device.
    func startRecording() throws {
        guard !isRecording else { return }
        
        // Reset buffer
        bufferLock.lock()
        audioBuffer = []
        bufferLock.unlock()
        
        let inputNode = audioEngine.inputNode
        
        // Configure format: 16kHz, mono, Float32 (Whisper requirement)
        let desiredSampleRate: Double = 16000
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: desiredSampleRate,
            channels: 1,
            interleaved: false
        )!
        
        // Install tap on input node with format conversion
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // If the hardware sample rate differs, we need a converter
        if inputFormat.sampleRate != desiredSampleRate {
            // Install tap at native format and convert
            let converter = AVAudioConverter(from: inputFormat, to: format)
            let ratio = desiredSampleRate / inputFormat.sampleRate
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, let converter = converter else { return }
                
                let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
                
                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                if status == .haveData {
                    if let channelData = convertedBuffer.floatChannelData?[0] {
                        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
                        self.bufferLock.lock()
                        self.audioBuffer.append(contentsOf: samples)
                        self.bufferLock.unlock()
                    }
                }
            }
        } else {
            // Sample rates match, install tap directly
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                if let channelData = buffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
                    self.bufferLock.lock()
                    self.audioBuffer.append(contentsOf: samples)
                    self.bufferLock.unlock()
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
        
        // Start streaming timer for periodic transcription (every 3.5 seconds)
        // Increased from 2s to give Whisper more context per chunk
        DispatchQueue.main.async {
            self.streamingTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
                self?.sendBufferForStreaming()
            }
        }
    }
    
    /// Stop recording and return the complete, preprocessed audio buffer.
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }
        
        // Stop streaming timer
        streamingTimer?.invalidate()
        streamingTimer = nil
        
        // Stop audio engine
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Return accumulated buffer with preprocessing
        bufferLock.lock()
        let rawBuffer = audioBuffer
        audioBuffer = []
        bufferLock.unlock()
        
        // Apply audio preprocessing for final transcription
        return preprocessAudio(rawBuffer)
    }
    
    /// Send current buffer snapshot for streaming transcription
    private func sendBufferForStreaming() {
        bufferLock.lock()
        let currentBuffer = audioBuffer
        bufferLock.unlock()
        
        guard !currentBuffer.isEmpty else { return }
        onBufferReady?(currentBuffer)
    }
    
    // MARK: - Audio Preprocessing
    
    /// Apply noise gate and normalization to improve Whisper accuracy
    private func preprocessAudio(_ buffer: [Float]) -> [Float] {
        guard !buffer.isEmpty else { return buffer }
        
        var processed = applyNoiseGate(buffer)
        processed = normalizeAudio(processed)
        
        return processed
    }
    
    /// Noise gate: silence frames below the RMS threshold to remove background noise
    private func applyNoiseGate(_ buffer: [Float]) -> [Float] {
        var result = buffer
        let frameCount = buffer.count / noiseGateFrameSize
        
        for i in 0..<frameCount {
            let start = i * noiseGateFrameSize
            let end = min(start + noiseGateFrameSize, buffer.count)
            let frame = Array(buffer[start..<end])
            
            // Calculate RMS of the frame
            let rms = calculateRMS(frame)
            
            // If below threshold, silence this frame
            if rms < noiseGateThreshold {
                for j in start..<end {
                    result[j] = 0.0
                }
            }
        }
        
        return result
    }
    
    /// Normalize audio to use the full dynamic range
    private func normalizeAudio(_ buffer: [Float]) -> [Float] {
        guard !buffer.isEmpty else { return buffer }
        
        // Find peak amplitude
        var peak: Float = 0.0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(buffer.count))
        
        // Avoid division by zero and don't amplify near-silent audio
        guard peak > 0.01 else { return buffer }
        
        // Normalize to 0.95 peak to avoid clipping
        let targetPeak: Float = 0.95
        let scale = targetPeak / peak
        
        var result = [Float](repeating: 0, count: buffer.count)
        var scaleVar = scale
        vDSP_vsmul(buffer, 1, &scaleVar, &result, 1, vDSP_Length(buffer.count))
        
        return result
    }
    
    /// Calculate RMS (Root Mean Square) of an audio frame
    private func calculateRMS(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0.0 }
        var meanSquare: Float = 0.0
        vDSP_measqv(frame, 1, &meanSquare, vDSP_Length(frame.count))
        return sqrt(meanSquare)
    }
}
