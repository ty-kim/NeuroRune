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
- [x] 61 unit tests, Swift Testing + TCA TestStore

### Sprint 2 — Memory & Voice (Apr 16-19)
- [ ] GitHub-backed memory sync
- [ ] Clova Note voice input
- [ ] Memory context injection
- [ ] File editing + commit

### Sprint 3 — Multi-LLM (Future)
- [ ] OpenAI (GPT-5, Codex)
- [ ] Provider-neutral LLMClient protocol

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

## License

[MIT](LICENSE)
