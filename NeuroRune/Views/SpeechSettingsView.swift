//
//  SpeechSettingsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 Slice 7 — 상세 TTS 설정 sheet (속도·피치 슬라이더).
//

import SwiftUI
import ComposableArchitecture

struct SpeechSettingsView: View {
    let store: StoreOf<ChatFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithViewStore(store, observe: { $0.speechSettings }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        HStack {
                            Text(String(localized: "settings.tts.rate"))
                            Spacer()
                            Text(String(format: "%.2fx", viewStore.rate))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: viewStore.binding(
                                get: \.rate,
                                send: ChatFeature.Action.speechRateChanged
                            ),
                            in: 0.5...1.5,
                            step: 0.05
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.rate.footer"))
                    }

                    Section {
                        HStack {
                            Text(String(localized: "settings.tts.pitch"))
                            Spacer()
                            Text(pitchLabel(viewStore.pitch))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: viewStore.binding(
                                get: \.pitch,
                                send: ChatFeature.Action.speechPitchChanged
                            ),
                            in: 0.5...1.5,
                            step: 0.05
                        )
                    } footer: {
                        Text(String(localized: "settings.tts.pitch.footer"))
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
            }
        }
    }

    private func pitchLabel(_ pitch: Double) -> String {
        let percent = Int((pitch - 1.0) * 100)
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }
}
