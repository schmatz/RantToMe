# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RantToMe is a macOS menu bar app for speech-to-text transcription. It runs entirely on-device using two ASR backends:
- **FluidAudio (Parakeet)**: Fast English (v2) and multilingual European (v3) models
- **WhisperKit**: 100+ language support via Whisper v3 Turbo

**Requirements**: macOS 15.6+ (Sequoia), Swift 5

**Model sizes** (downloaded on first use):
- Parakeet v2 (English): ~900 MB
- Parakeet v3 (multilingual): ~900 MB
- Whisper v3 Turbo: ~950 MB

## Build Commands

```bash
# Build from command line
xcodebuild -project RantToMe.xcodeproj -scheme RantToMe -configuration Debug build

# Run tests
xcodebuild -project RantToMe.xcodeproj -scheme RantToMe test
```

Or open `RantToMe.xcodeproj` in Xcode and use Cmd+B / Cmd+R.

## Testing

Tests use Swift Testing framework (not XCTest). Run with `@Suite(.serialized)` to avoid concurrent model loading issues. Current tests verify model loading for all three ASR backends.

## Architecture

### App Structure
- **Menu bar app** with floating record window (no dock icon by default)
- Main window only opens when explicitly requested (transcription history view)
- Global hotkey support via Carbon Events API (Cmd+D default)

### Core Components

**AppState** (`ViewModels/AppState.swift`):
- Central observable state machine with modes: `downloadRequired` → `loadingModel` → `ready` ↔ `recording` → `transcribing`
- Manages transcription history (persisted to Application Support)
- Handles auto-copy to clipboard, sound effects, and notifications

**TranscriptionService** (`Services/TranscriptionService.swift`):
- Abstracts over FluidAudio and WhisperKit backends
- Models auto-download from HuggingFace on first use
- `AppModelVersion` enum defines available models (parakeetV2, parakeetV3, whisperV3Turbo)

**GlossaryManager** (`Services/GlossaryManager.swift`):
- Post-processing text replacements (e.g., "gonna" → "going to")
- Applied after transcription, before clipboard copy

**GlobalHotKeyManager** (`Services/GlobalHotKeyManager.swift`):
- Uses Carbon Events API for system-wide hotkey capture
- Configurable via Settings (stored in HotKeySettings)

**AudioRecorder** (`Services/AudioRecorder.swift`):
- Records 16kHz mono WAV (16-bit PCM) for ASR compatibility
- Minimum 1-second recording duration enforced

### Key Dependencies (Swift Package Manager)
- `FluidAudio` - FluidInference's Parakeet ASR
- `WhisperKit` - argmax's on-device Whisper implementation

### Data Storage
- Transcription history: `~/Library/Application Support/RantToMe/transcription_history.json`
- Glossary entries: `~/Library/Application Support/glossary.json`
- Model cache: `~/Library/Application Support/FluidAudio/` and `~/.cache/huggingface/`

### Entitlements
- App Sandbox enabled
- Microphone access required
- Network client (for model downloads)
- User-selected file read (for drag-and-drop audio files)

## Model Download Security

Models are downloaded from HuggingFace with security measures:

- **Revision pinning**: Each model is pinned to a specific commit hash (see `ModelDownloadService.swift`)
- **Hash verification**: LFS files are verified against their SHA256 hashes
- **Fail-hard policy**: Verification failures block model loading and show a clear error

To update pinned model versions, see the "Maintaining Model Versions" section in `SECURITY_AUDIT.md`.

Key files:
- `Services/ModelDownloadService.swift` - Secure download with pinned revisions
- `SECURITY_AUDIT.md` - Full security documentation
