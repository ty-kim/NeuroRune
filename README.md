# NeuroRune

[![CI](https://github.com/ty-kim/NeuroRune/actions/workflows/ci.yml/badge.svg)](https://github.com/ty-kim/NeuroRune/actions/workflows/ci.yml)

Sessions die, memory carries on.

An AI-native iOS app that turns your LLM conversations — voice or text —
into GitHub-synced personal memory.

## Screenshots

| <img src="Screenshots/Screenshot03.png" alt="Reviewable memory write flow with explicit user approval" width="320" /> | <img src="Screenshots/Screenshot02.png" alt="Streaming chat UI with long-form responses and voice playback" width="320" /> |
| --- | --- |
| Reviewable memory write flow with explicit user approval | Streaming chat UI with long-form responses and voice playback |

## Overview

Every LLM session starts from zero. Context resets, decisions evaporate,
the conversation you had yesterday is gone. NeuroRune solves this by
turning raw conversations into distilled memory files, synced to a
user-owned GitHub repository, and carried forward into future sessions.

Think of it as memory consolidation — the same process your brain runs
during sleep, moving short-term experience into long-term knowledge.
NeuroRune does this for your AI sessions.

Built as a BYOK (Bring Your Own Key) app: you provide your own API keys,
the app keeps them in Keychain, and nothing is bundled with the binary.

The interesting problems here are not vendor-specific. NeuroRune is built
around streaming LLM responses, persistent memory, tool use, STT, and TTS,
with those integrations kept behind client boundaries so providers can be
swapped without rewriting the whole app. The current live setup uses
Anthropic for LLM, Groq Whisper for STT, and ElevenLabs for TTS.

## Highlights

- Streaming chat UX with session-based model selection, persistence, and
  failure handling
- User-owned memory on GitHub, with `read_memory` / `write_memory` flows
  and explicit approval before writes
- Voice input and output through STT / TTS clients, kept separate from
  product logic
- Consolidation flow that turns recent chats into reviewable memory
  proposals
- Engineering quality signals: Swift 6 strict concurrency, strict CI
  (SwiftLint + build/test), 393 unit tests, 3 UI smoke tests,
  localization, and accessibility support
- Provider boundaries (`LLMClient`, `STTClient`, `SpeakerClient`) so the
  app layer is not tied to a single model or speech vendor

## Implemented

### Chat ✅
- [x] Streaming LLM integration (Anthropic)
- [x] Keychain-secured credentials (save/load/delete + reset UI)
- [x] Persistent chat sessions (SwiftData, conversation list, delete)
- [x] Markdown rendering (swift-markdown-ui, code block horizontal scroll)
- [x] Session-based model selection (model picker sheet)
- [x] OSLog logging (network, keychain, llm, persistence)
- [x] Localization (ko, en, zh-Hans, zh-Hant, ja)
- [x] Accessibility (VoiceOver labels, Reduce Motion)
- [x] Error UI (banner + shake + 401 alert)
- [x] App icon (ᛗ Mannaz rune), brand colors (amber + dark navy)
- [x] Launch screen (DarkNavy + Mannaz rune)
- [x] 393 unit tests, Swift Testing + TCA TestStore
- [x] 3 UI smoke tests

### Memory ✅
- [x] GitHub-backed memory sync (.global / .local roles, PAT auth)
- [x] User-driven memory editing + commit (MemoryEditView / MemoryCreateView)
- [x] Memory context injection (MEMORY.md auto + read_memory tool for dynamic load)
- [x] Tool-call transparency UI (chip showing which memory file the model is reading)
- [x] write_memory tool with confirm modal (role/path/commit/content → user accept)

### Voice & Consolidation ✅
- [x] STT integration (Groq Whisper)
- [x] TTS integration (ElevenLabs)
- [x] Consolidation (collect recent chat + memory → LLM proposal → accept/reject UI)

## Stack

- Swift 6 Strict Concurrency
- SwiftUI
- SwiftData
- TCA (The Composable Architecture)
- URLSession (first-party networking)
- AVFoundation
- swift-markdown-ui
- Keychain Services

## Architecture

```text
SwiftUI Views
    ↕
TCA Reducers / State
    ↕
Client Boundaries
    ├─ LLMClient
    ├─ STTClient
    ├─ SpeakerClient
    ├─ GitHubClient
    └─ KeychainClient
    ↕
Provider-specific integrations
```

Current bindings:

- LLM: Anthropic
- STT: Groq Whisper
- TTS: ElevenLabs
- Memory sync: GitHub REST API

## Requirements

- iOS 17+
- LLM API key (Anthropic)
- GitHub Personal Access Token (memory sync)
- STT API key (Groq Whisper)
- TTS API key (ElevenLabs)

## Known Limitations

- **Markdown rendering is unbounded.** Assistant responses are passed
  directly to MarkdownUI without length/depth caps or a render timeout.
  In a single-user BYOK app the threat model is narrow (your own LLM
  reply on your own device), but a pathological response can still hang
  the UI. Use lower `effort` levels to keep responses bounded, and watch
  swift-cmark for parser CVEs.

## Inspired by

Gibson's cyberspace is a space for data. Cogspace is a space for thought:
human and AI reasoning across time instead of starting over every session.
NeuroRune turns that idea into an AI-native mobile product.

Its memory model borrows from *Infinity Blade* (Epic Games, 2010): each
generation inherits what the previous one learned. Here, the "generation"
is the next model session, and the inheritance is user-owned memory.

## License

[MIT](LICENSE)
