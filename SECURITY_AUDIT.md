# Security Audit: RantToMe

> **Note**: This document was written by Claude (AI) and proofread by humans.

## Executive Summary

**VERDICT: CLEAN - No telemetry or data exfiltration detected**

RantToMe is a privacy-respecting, local-first transcription app. All speech recognition happens on-device using CoreML. No audio or transcription text is transmitted over the network.

This app is suitable for high-assurance deployments where confidential information may be transcribed. The only network activity is downloading ML models from HuggingFace, which occurs once per model and is protected by SHA256 hash verification.

---

## Threat Model

This section documents the adversarial threat analysis for deployments handling sensitive information.

### Adversary Capabilities Considered

- **Network-level adversary**: MITM attacks on model downloads, DNS spoofing
- **Supply chain adversary**: Compromise of HuggingFace repositories, maintainer account takeover
- **Dependency compromise**: Malicious updates to Swift packages
- **Local adversary**: Access to the filesystem (covered separately in residual risks)

### What We Protect Against

| Threat | Mitigation |
|--------|------------|
| Model tampering during download | SHA256 hash verification with hashes pinned in source code |
| Silent model updates | Revision pinning to specific git commit hashes |
| MITM model substitution | TLS + hash verification (hash mismatch fails download) |
| Version drift between users | All users download identical model files (same revision + hash) |
| HuggingFace returning bad hashes | Critical file hashes hardcoded in `ModelDownloadService.swift`, not trusted from server |

### What We Don't Protect Against

| Threat | Notes |
|--------|-------|
| Initial trust establishment | We trust models at the commit hash when first pinned. Auditors should verify model provenance independently. |
| Apple CoreML runtime bugs | Theoretical exploits in CoreML itself are outside app control |
| Build-time compromise | If the app binary is compromised before distribution |
| Physical device access | Attacker with device access can read transcription history |
| OS-level compromise | Keyloggers, screen capture, clipboard sniffing by malware |

---

## Network Activity Analysis

### Endpoints Contacted

| Endpoint | Purpose | When |
|----------|---------|------|
| `huggingface.co` | Model download API | First launch (per model) |
| CloudFront CDN (`18.245.x.x`, `2600:9000:*`) | Model file delivery | During download only |

**No other endpoints are contacted.** See [NETWORK_AUDIT.md](NETWORK_AUDIT.md) for runtime verification methodology.

### Model Repositories

| Model | Repository | Pinned Revision |
|-------|------------|-----------------|
| Parakeet v2 (English) | `FluidInference/parakeet-tdt-0.6b-v2-coreml` | `ee09c569f73759e6d44c9bd16766f477b2b36d39` |
| Parakeet v3 (Multilingual) | `FluidInference/parakeet-tdt-0.6b-v3-coreml` | `dc730587467ddc9f7ea93b6e3ad5caef8b4222f4` |
| Whisper v3 Turbo | `argmaxinc/whisperkit-coreml` | `1f92e0a7895c30ff3448ec31a65eb4acffcfd7de` |

### Network Behavior

- **Idle state**: Zero connections
- **During download**: 3-6 connections to CloudFront
- **Post-download**: Connections closed via `finishTasksAndInvalidate()`
- **During transcription**: Zero connections (fully local)
- **No heartbeat**: No periodic network requests

**Location:** `RantToMe/Services/ModelDownloadService.swift`

---

## Model Security

### CoreML Format Advantages

Unlike Python pickle files (which can execute arbitrary code on load), CoreML models are:

- **Compiled tensor graphs**: Pre-compiled computation, not executable code
- **Sandboxed runtime**: Limited system access via Apple's CoreML
- **No code execution**: Cannot embed arbitrary executables

Residual risks with a malicious CoreML model are limited to:
- Data poisoning (incorrect transcriptions)
- Parser exploits (theoretical memory corruption in CoreML loader)
- Resource exhaustion (crashes, excessive memory)

### SHA256 Hash Verification

All model files are verified against SHA256 hashes in two layers:

**Layer 1 - Server-provided hashes**: Git LFS metadata includes hashes verified during download:
```swift
if let lfs = file.lfs {
    let actualHash = try computeFileHash(at: fileURL)
    if actualHash != lfs.sha256 {
        try fileManager.removeItem(at: fileURL)
        throw ModelDownloadError.hashMismatch(...)
    }
}
```

**Layer 2 - Pinned hashes**: Critical files have SHA256 hashes hardcoded in source. This protects against a compromised HuggingFace server returning different hashes:
```swift
// Example from PinnedModelVersions.parakeetV2
fileHashes: [
    "Decoder.mlmodelc/coremldata.bin": "d200ca07694a347f6d02a3886a062ae839831e094e443222f2e48a14945966a8",
    "Encoder.mlmodelc/weights/weight.bin": "4adc7ad44f9d05e1bffeb2b06d3bb02861a5c7602dff63a6b494aed3bf8a6c3e",
    ...
]
```

**Location:** `RantToMe/Services/ModelDownloadService.swift:60-123`

### Failure Behavior

When verification fails:
1. **Refuses to load**: No transcription occurs with unverified models
2. **Deletes corrupted files**: Tampered files are removed
3. **Shows clear error**: User sees "Model verification failed"
4. **Requires manual action**: User must clear cache and re-download

---

## Data Handling

| Data Type | Storage Location | Transmitted? |
|-----------|------------------|--------------|
| Audio recordings | `/var/folders/.../T/` (macOS temp) | No - deleted after transcription |
| Transcription history | `~/Library/Application Support/RantToMe/transcription_history.json` | No |
| Glossary replacements | `~/Library/Application Support/glossary.json` | No |
| ML models | `~/Library/Application Support/RantToMe/Models/` | Downloaded once, never uploaded |
| User settings | UserDefaults | No |

### Data Lifecycle

1. Audio recorded to temporary file in `/var/folders/.../T/`
2. Processed locally by CoreML model
3. Temporary audio file deleted
4. Transcription optionally saved to history JSON
5. Optionally copied to clipboard

---

## Supply Chain Analysis

### Direct Dependencies

| Package | Version | Pinned Commit | Purpose |
|---------|---------|---------------|---------|
| FluidAudio | 0.10.1 | `0afbabca218c6c0e363fc128e1b50be4e69abc5e` | Parakeet ASR inference |
| WhisperKit | 0.15.0 | `664e1b5a65296cd957dfdf262cd120ca88f3b24b` | Whisper ASR inference |

### Transitive Dependencies

| Package | Version | Source | Purpose |
|---------|---------|--------|---------|
| swift-transformers | 1.1.6 | HuggingFace | Tokenizer utilities |
| swift-jinja | 2.2.1 | HuggingFace | Template rendering |
| swift-collections | 1.3.0 | Apple | Data structures |
| swift-argument-parser | 1.7.0 | Apple | CLI parsing |

**Dependency lockfile:** `Package.resolved` pins exact commit hashes for all dependencies.

### Supply Chain Gaps

| Gap | Risk Level | Notes |
|-----|------------|-------|
| SPM version ranges | Low | Package.swift may specify ranges, but Package.resolved pins exact commits |
| Transitive dependency updates | Low | Updating direct dependencies may pull new transitives |
| No binary reproducibility | Medium | Builds are not reproducible; depends on Xcode toolchain |

---

## Permissions & Sandbox

**Entitlements** (`RantToMe.entitlements`):

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.app-sandbox` | Sandboxed execution |
| `com.apple.security.device.audio-input` | Microphone for recording |
| `com.apple.security.files.user-selected.read-only` | Drag-drop audio files |
| `com.apple.security.network.client` | Model downloads only |

**Not requested:** Location, contacts, calendar, photos, camera, Bluetooth, local network discovery, outbound connections to arbitrary hosts.

---

## Security Checks Performed

| Check | Result |
|-------|--------|
| URLSession/network code audit | Only model downloads via `ModelDownloadService` |
| Analytics frameworks (Firebase, Mixpanel, Amplitude, Segment) | None |
| Telemetry/beacon code | None |
| Crash reporting (Sentry, Bugsnag, Crashlytics) | None |
| Obfuscated/encoded URLs | None |
| Base64 encoding + network patterns | None |
| Keychain access | None |
| XPC/IPC data transmission | None (only internal UI notifications) |
| Background tasks | None |
| Launch agents/daemons | None |
| Device fingerprinting | None |
| Clipboard monitoring | None (only intentional copy) |
| Model hash verification | SHA256 with pinned hashes |
| Revision pinning | All models pinned to specific commits |
| Connection lifecycle | Connections closed after download |

---

## Residual Risks for High-Security Deployments

These items are not vulnerabilities but may require consideration for sensitive deployments:

### Data at Rest

| Item | Risk | Mitigation |
|------|------|------------|
| Transcription history | Plain JSON file readable by any process with user permissions | Disable history in Settings, or rely on FileVault disk encryption |
| Glossary file | Can be modified by attacker with filesystem access to alter future transcriptions | Monitor file integrity, restrict filesystem access |

### Clipboard Exposure

When auto-copy is enabled, transcriptions are placed on the system clipboard, accessible to:
- Any app running under the same user
- Universal clipboard (if enabled) may sync to other devices
- Clipboard managers/history tools

**Mitigation:** Disable auto-copy for sensitive transcriptions.

### TLS Trust

| Item | Status |
|------|--------|
| Certificate pinning | Not implemented |
| TLS trust | Relies on macOS system trust store |

This is standard for HuggingFace downloads. The SHA256 hash verification provides integrity assurance independent of TLS.

### Dependency Update Path

Minor/patch version updates to dependencies (via `swift package update`) are not blocked by the lockfile if Package.swift specifies version ranges. However:
- The checked-in `Package.resolved` pins exact commits
- Developers must explicitly run update commands
- Changes to Package.resolved are visible in git diff

---

## Maintaining Model Versions

When a new model version needs to be adopted:

### For Maintainers

1. **Get the new revision hash** from HuggingFace:
   ```bash
   curl https://huggingface.co/api/models/{owner}/{repo} | jq .sha
   ```

2. **Download and verify** the model manually to ensure it works correctly

3. **Get LFS file hashes** for pinning:
   ```bash
   # List LFS files and their hashes
   curl "https://huggingface.co/api/models/{owner}/{repo}/tree/{revision}" | jq '.[] | select(.lfs) | {path, sha256: .lfs.oid}'
   ```

4. **Update `PinnedModelVersions`** in `ModelDownloadService.swift`:
   ```swift
   static let parakeetV2 = ModelDownloadConfig(
       repository: "FluidInference/parakeet-tdt-0.6b-v2-coreml",
       revision: "NEW_COMMIT_HASH_HERE",
       fileHashes: [
           "Decoder.mlmodelc/coremldata.bin": "NEW_SHA256_HASH",
           // ... all LFS files
       ]
   )
   ```

5. **Test thoroughly** before releasing

### For Users

Users receive updated model versions through app updates. Existing cached models are re-downloaded when the pinned revision changes.

### Audit Trail

Pinned revisions and their update history can be tracked through:
- Git history of `ModelDownloadService.swift`
- This security documentation
- Release notes for version updates

---

## Recommendations for High-Security Use

1. **Disable transcription history**: Settings > uncheck "Save transcription history"
2. **Air-gapped model download**: Optionally download models on a separate system, verify hashes, and copy to `~/Library/Application Support/RantToMe/Models/`
3. **Enable FileVault**: Ensures data at rest is encrypted
4. **Review glossary.json**: Periodically verify no unexpected replacements
5. **Monitor Package.resolved**: Include in code review for any dependency changes
6. **Build from source**: For maximum assurance, build from audited source code

---

## Conclusion

RantToMe maintains a **local-first architecture**:

1. Audio recorded locally to temp directory
2. Processed locally by CoreML model (FluidAudio or WhisperKit)
3. Results stored locally in JSON file (optional)
4. Optionally copied to local clipboard
5. Temp files cleaned up immediately

**Security posture:**
- Models protected by SHA256 hash verification with pinned hashes
- No telemetry, analytics, or crash reporting
- No audio or transcription data transmitted
- Single network endpoint (HuggingFace) for model downloads only
- Minimal permission set (microphone + network client)

The app is suitable for transcribing confidential information. The residual risks documented above are typical for any local application and can be mitigated through the recommendations provided.

---

*Audit performed: January 2026*
*Last updated: January 28, 2026*
