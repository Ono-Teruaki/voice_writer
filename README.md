# VoiceWriter

VoiceWriter is a macOS menu bar app that records speech, transcribes it with Whisper, and pastes the recognized text into the currently active app.

## Features

- Global hotkey (`⌘⌥V`) to start/stop recording
- Real-time overlay with streaming transcription preview
- Japanese-focused transcription settings via WhisperKit
- Automatic paste into the active application after processing

## Architecture

The app is built as a Swift Package and organized around a central state coordinator.

- `VoiceWriterApp` (`Sources/VoiceWriter/VoiceWriterApp.swift`)
  - Menu bar entry point and status UI
- `AppState` (`Sources/VoiceWriter/AppState.swift`)
  - Orchestrates recording, transcription, overlay display, and text input
- `AudioRecorder` (`Sources/VoiceWriter/AudioRecorder.swift`)
  - Captures microphone input, converts to 16kHz mono Float32, applies preprocessing
- `WhisperTranscriber` (`Sources/VoiceWriter/WhisperTranscriber.swift`)
  - Loads Whisper model via WhisperKit and performs transcription/post-processing
- `OverlayPanel` + `OverlayView`
  - Floating non-activating UI panel for recording/transcription feedback
- `TextInputSimulator` (`Sources/VoiceWriter/TextInputSimulator.swift`)
  - Pastes final text into the active app (AppleScript, fallback CGEvent)
- `HotkeyManager` (`Sources/VoiceWriter/HotkeyManager.swift`)
  - Registers global hotkey through `HotKey`

### Data flow

1. User presses `⌘⌥V`
2. `AppState` starts `AudioRecorder`
3. `AudioRecorder` sends periodic buffers for streaming transcription
4. `WhisperTranscriber` updates overlay text
5. User presses `⌘⌥V` again
6. Final transcription is post-processed and pasted into the active app

## Requirements

- macOS 14+
- Xcode command line tools (`xcode-select --install`)
- Internet connection on first launch (model download)

## Build and Run

### Run from source

```bash
swift build
swift run VoiceWriter
```

### Build `.app` bundle

```bash
./scripts/build.sh
open VoiceWriter.app
```

## Permissions

VoiceWriter requires the following macOS permissions:

- **Microphone**: to capture voice input
- **Accessibility**: to paste transcribed text into other apps

You can grant them in:

- `System Settings > Privacy & Security > Microphone`
- `System Settings > Privacy & Security > Accessibility`

## Notes

- The first model initialization may download about **950MB** (`large-v3-turbo`).
- Recognition quality depends on microphone quality and background noise.

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- [HotKey](https://github.com/soffes/HotKey)

## License

MIT License. See `LICENSE`.

