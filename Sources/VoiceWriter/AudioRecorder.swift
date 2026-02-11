import AVFoundation
import Combine

/// Manages audio recording from the microphone using AVAudioEngine.
/// Captures audio in 16kHz mono Float32 format suitable for Whisper input.
final class AudioRecorder: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    
    /// Timer for periodic transcription updates
    private var streamingTimer: Timer?
    
    /// Callback invoked periodically with the accumulated audio buffer for streaming transcription
    var onBufferReady: (([Float]) -> Void)?
    
    @Published var isRecording = false
    
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
        
        // Start streaming timer for periodic transcription (every 2 seconds)
        DispatchQueue.main.async {
            self.streamingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.sendBufferForStreaming()
            }
        }
    }
    
    /// Stop recording and return the complete audio buffer.
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
        
        // Return accumulated buffer
        bufferLock.lock()
        let finalBuffer = audioBuffer
        audioBuffer = []
        bufferLock.unlock()
        
        return finalBuffer
    }
    
    /// Send current buffer snapshot for streaming transcription
    private func sendBufferForStreaming() {
        bufferLock.lock()
        let currentBuffer = audioBuffer
        bufferLock.unlock()
        
        guard !currentBuffer.isEmpty else { return }
        onBufferReady?(currentBuffer)
    }
}
