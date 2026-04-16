//
//  ChatTTSMenu.swift
//  NeuroRune
//
//  Created by tykim
//
//  ChatView 우상단 TTS toolbar Menu. autoSpeak 토글·voice 선택·상세 설정 진입.
//

import SwiftUI
import ComposableArchitecture

struct ChatTTSMenu: View {
    let store: StoreOf<ChatFeature>

    var body: some View {
        WithViewStore(store, observe: { $0.speechSettings }) { viewStore in
            Menu {
                Toggle(
                    String(localized: "settings.tts.autoSpeak"),
                    isOn: viewStore.binding(
                        get: \.autoSpeak,
                        send: ChatFeature.Action.autoSpeakToggled
                    )
                )
                Section(String(localized: "settings.tts.voice")) {
                    ForEach(AzureVoice.presets) { voice in
                        Button {
                            viewStore.send(.speechVoiceSelected(voice.name))
                        } label: {
                            if viewStore.voiceName == voice.name {
                                Label(voice.displayName, systemImage: "checkmark")
                            } else {
                                Text(voice.displayName)
                            }
                        }
                    }
                }
                Button {
                    viewStore.send(.speechSettingsTapped)
                } label: {
                    Label(
                        String(localized: "settings.tts.detail"),
                        systemImage: "slider.horizontal.3"
                    )
                }
            } label: {
                Image(systemName: viewStore.autoSpeak ? "speaker.wave.3" : "speaker.wave.2")
                    .font(.title3)
            }
            .accessibilityLabel(String(localized: "a11y.chat.ttsSettings"))
        }
    }
}
