//
//  SpeechSettingsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS 상세 설정 sheet. voice 동적 리스트 + stability/similarity/style slider + speakerBoost toggle.
//

import SwiftUI
import ComposableArchitecture

struct SpeechSettingsView: View {
    let store: StoreOf<ChatFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var voices: [ElevenLabsVoice] = []
    @State private var voicesLoading = false
    @State private var voicesError: String?

    var body: some View {
        WithViewStore(store, observe: { $0.speechSettings }) { viewStore in
            NavigationStack {
                Form {
                    voiceSection(viewStore: viewStore)

                    Section {
                        slider(
                            label: String(localized: "settings.tts.stability"),
                            value: viewStore.binding(
                                get: \.stability,
                                send: ChatFeature.Action.speechStabilityChanged
                            )
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.stability.footer"))
                    }

                    Section {
                        slider(
                            label: String(localized: "settings.tts.similarity"),
                            value: viewStore.binding(
                                get: \.similarityBoost,
                                send: ChatFeature.Action.speechSimilarityChanged
                            )
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.similarity.footer"))
                    }

                    Section {
                        slider(
                            label: String(localized: "settings.tts.style"),
                            value: viewStore.binding(
                                get: \.style,
                                send: ChatFeature.Action.speechStyleChanged
                            )
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.style.footer"))
                    }

                    Section {
                        Toggle(
                            String(localized: "settings.tts.speakerBoost"),
                            isOn: viewStore.binding(
                                get: \.useSpeakerBoost,
                                send: ChatFeature.Action.speechSpeakerBoostToggled
                            )
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.speakerBoost.footer"))
                    }
                }
                .navigationTitle(String(localized: "settings.tts.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "onboarding.save")) {
                            dismiss()
                        }
                    }
                }
                .task {
                    await loadVoices()
                }
            }
        }
    }

    @ViewBuilder
    private func voiceSection(viewStore: ViewStore<SpeechSettings, ChatFeature.Action>) -> some View {
        Section {
            if voicesLoading {
                HStack {
                    ProgressView()
                    Text(String(localized: "settings.tts.voice.loading"))
                        .foregroundStyle(.secondary)
                }
            } else if let error = voicesError {
                Text(error).font(.caption).foregroundStyle(.red)
                Button(String(localized: "settings.tts.voice.retry")) {
                    Task { await loadVoices() }
                }
            } else if voices.isEmpty {
                Text(String(localized: "settings.tts.voice.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(voices) { voice in
                    Button {
                        viewStore.send(.speechVoiceSelected(voiceId: voice.id, voiceName: voice.name))
                    } label: {
                        HStack {
                            Text(voice.name).foregroundStyle(.primary)
                            Spacer()
                            if viewStore.voiceId == voice.id {
                                Image(systemName: "checkmark").foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.tts.voice"))
        }
    }

    private func slider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0.0...1.0, step: 0.05)
        }
    }

    private func loadVoices() async {
        voicesLoading = true
        voicesError = nil
        defer { voicesLoading = false }
        do {
            voices = try await ElevenLabsClient.liveValue.listVoices()
        } catch let e as SpeechError {
            voicesError = String(localized: String.LocalizationValue(e.userMessageKey))
        } catch {
            voicesError = error.localizedDescription
        }
    }
}
