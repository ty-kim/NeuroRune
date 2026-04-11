# NeuroRune

iOS chat client for Claude with persistent, GitHub-synced memory.

## Overview

NeuroRune is a personal mobile client for the Anthropic Claude API.
Conversations are stored as Markdown files, synced to a user-owned GitHub
repository, and injected into future sessions as context — carrying notes,
decisions, and learnings forward across sessions.

Built as a BYOK (Bring Your Own Key) app: you provide your own Anthropic
API key, GitHub Personal Access Token, and optionally a Clova Note STT key.
No API keys are bundled with the app.

## Inspired by

Inspired by the Bloodline system from *Infinity Blade* (Epic Games, 2010) —
where a character's death passes experience and gear to the next generation.
NeuroRune applies the same pattern to LLM sessions: each conversation adds
to a memory a future session can inherit from.

## Roadmap

### Sprint 1 — Chat (Apr 11-15)
- [ ] Claude API integration
- [ ] Keychain-secured credentials
- [ ] Persistent chat sessions
- [ ] Markdown rendering
- [ ] Session-based model selection

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

Private — personal project by Kim Tae-yeon (ty-kim)
