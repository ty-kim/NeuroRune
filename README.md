# NeuroRune

iOS client for Claude. Sessions die, memory carries on.

## Overview

Every LLM session starts from zero. Context resets, decisions evaporate,
the conversation you had yesterday is gone. NeuroRune solves this by
turning raw conversations into distilled memory files, synced to a
user-owned GitHub repository, and carried forward into future sessions.

Think of it as memory consolidation — the same process your brain runs
during sleep, moving short-term experience into long-term knowledge.
NeuroRune does this for your AI sessions.

Built as a BYOK (Bring Your Own Key) app: you provide your own Anthropic
API key, GitHub Personal Access Token, and optionally a Clova Note STT key.
No API keys are bundled with the app.

## Inspired by

Gibson's cyberspace is a space for data. Cogspace is a space for thought —
human and AI, thinking together. NeuroRune connects you to it.

Memory inheritance is borrowed from *Infinity Blade* (Epic Games, 2010):
each generation passes what it learned to the next.

## Roadmap

### Sprint 1 — Chat (Apr 11-15) ✅
- [x] Claude API integration (AnthropicClient, error parsing)
- [x] Keychain-secured credentials (save/load/delete + reset UI)
- [x] Persistent chat sessions (SwiftData, conversation list, delete)
- [x] Markdown rendering (swift-markdown-ui, code block horizontal scroll)
- [x] Session-based model selection (model picker sheet)
- [x] OSLog logging (network, keychain, llm, persistence)
- [x] Localization (ko, en, zh-Hans, ja)
- [x] Accessibility (VoiceOver labels, Reduce Motion)
- [x] Error UI (banner + shake + 401 alert)
- [x] App icon (ᛗ Mannaz rune), brand colors (amber + dark navy)
- [x] Launch screen (DarkNavy + Mannaz rune)
- [x] 168 unit tests, Swift Testing + TCA TestStore

### Sprint 2 — Memory (Apr 13~)
- [x] GitHub-backed memory sync (.global / .local roles, PAT auth)
- [x] User-driven memory editing + commit (MemoryEditView / MemoryCreateView)
- [x] Memory context injection (MEMORY.md auto + read_memory tool for dynamic load)
- [ ] Tool-call transparency UI (chip showing which file Claude is reading)
- [ ] write_memory tool with confirm modal (file name + diff → user accept)

### Sprint 3 — Voice & Consolidation (Future)
- [ ] Clova Note voice input
- [ ] Consolidation (raw chat → distilled memory proposals)

## Stack

- Swift 6 Strict Concurrency
- SwiftUI
- TCA (The Composable Architecture)
- URLSession (first-party networking)
- swift-markdown-ui
- Keychain Services

## Requirements

- iOS 17+
- Anthropic API key (BYOK)
- GitHub Personal Access Token (Sprint 2+)

## Known Limitations

- **Markdown rendering is unbounded.** Assistant responses are passed
  directly to MarkdownUI without length/depth caps or a render timeout.
  In a single-user BYOK app the threat model is narrow (your own LLM
  reply on your own device), but a pathological response can still hang
  the UI. Use lower `effort` levels to keep responses bounded, and watch
  swift-cmark for parser CVEs.

## License

[MIT](LICENSE)
