# RantToMe

A macOS menu bar app for on-device speech-to-text transcription. All processing happens locally—no cloud services, no data leaves your machine.

> **Note**: This document was written by Claude (AI) and proofread by humans.

## Requirements

- macOS 15.6+ (Sequoia)
- Xcode with Swift 5
- Microphone permission (granted on first use)
- Disk space for models (900–950 MB depending on model choice)

## Features

- Menu bar interface with floating record window
- Three ASR models: Parakeet v2 (English), Parakeet v3 (European languages), Whisper v3 Turbo (100+ languages)
- Global hotkey support (default: ⌘+D, configurable in Settings)
- Transcription history with search
- Auto-copy to clipboard
- Glossary for text replacements (e.g., "gonna" → "going to")
- Drag-and-drop audio file transcription
- Optional sound effects

## Building with Your Own Certificate

### Step-by-step

1. Open `RantToMe.xcodeproj` in Xcode
2. Select the project in the navigator (top item in the left sidebar)
3. Select the **RantToMe** target
4. Go to **Signing & Capabilities** tab
5. Change **Team** to your Apple Developer team
6. Update **Bundle Identifier** to your organization's convention (e.g., `com.yourorg.transcription`)
7. Xcode will automatically provision with your certificate

### Build Commands

**From Xcode:**
- Build: Cmd+B
- Run: Cmd+R

**From command line:**
```bash
# Build
xcodebuild -project RantToMe.xcodeproj -scheme RantToMe -configuration Debug build

# Run tests
xcodebuild -project RantToMe.xcodeproj -scheme RantToMe test
```

### Entitlements

The entitlements are already configured correctly:
- App Sandbox (enabled)
- Microphone access
- Network client (for model downloads from HuggingFace)
- User-selected file read (for drag-and-drop)

No changes needed unless you require additional capabilities.

## Distribution (Direct Download)

To distribute the app outside the Mac App Store (e.g., from your website), you need to archive, notarize, and package it.

### 1. Archive the App

**In Xcode:**
1. Select **Product → Archive**
2. Wait for the build to complete
3. The Organizer window opens automatically

**From command line:**
```bash
xcodebuild -project RantToMe.xcodeproj -scheme RantToMe -configuration Release archive -archivePath build/RantToMe.xcarchive
```

### 2. Notarize and Export

Notarization is required for apps distributed outside the App Store on macOS 10.15+. Apple scans your app and issues a ticket that Gatekeeper accepts.

**In Xcode Organizer:**
1. Select your archive and click **Distribute App**
2. Choose **Direct Distribution**
3. Select **Upload** (sends to Apple for notarization)
4. Wait for notarization to complete (usually 1-5 minutes)
5. Once approved, click **Export App**
6. Choose a destination folder

The exported `.app` is now notarized and ready for distribution. For internal testing, just zip this up and that should be sufficient.

### 3. Create a DMG

A DMG provides a nice drag-to-install experience. You probably don't need this for internal distribution (just a zip file will do). Use the included script:

```bash
./scripts/create-dmg.sh "/path/to/RantToMe.app"
```

This creates `RantToMe.dmg` with:
- App icon on the left
- Applications folder shortcut on the right
- Custom DMG icon matching the app

## Usage

1. **Start recording**: Click the menu bar icon, use the floating window button, or press the global hotkey (⌘+D)
2. **Stop recording**: Same action again—click, button, or hotkey
3. **View transcription**: Text is automatically copied to clipboard; also appears in transcription history
4. **Access settings**: Click menu bar icon → Settings
5. **View history**: Click menu bar icon → Show History

## Model Information

| Model | Download Size | Languages | Notes |
|-------|---------------|-----------|-------|
| Parakeet v2 | ~900 MB | English only | Fastest, best for English |
| Parakeet v3 | ~900 MB | 25 European | Balanced speed/coverage |
| Whisper v3 Turbo | ~950 MB | 100+ | Most languages, slower |

Models download automatically on first use from HuggingFace.

## Security

- **On-device processing**: All transcription happens locally
- **Verified model downloads**: Models are pinned to specific HuggingFace commit hashes with SHA256 verification
- **Sandboxed**: Minimal entitlements, no unnecessary permissions
- **No telemetry**: No analytics or data collection

See `SECURITY_AUDIT.md` for full security documentation and model version maintenance procedures.

## Data Storage

| Data | Location |
|------|----------|
| Transcription history | `~/Library/Application Support/RantToMe/transcription_history.json` |
| Glossary | `~/Library/Application Support/glossary.json` |
| Parakeet models | `~/Library/Application Support/FluidAudio/` |
| Whisper models | `~/.cache/huggingface/` |
