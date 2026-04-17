//
//  ChatTTSMenu.swift
//  NeuroRune
//
//  Created by tykim
//
//  ChatView 우상단 TTS toolbar Menu. autoSpeak 토글 + 현재 voice 표시 + 상세 설정 진입.
//  voice 선택은 상세 설정 sheet에서 (동적 API 호출).
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
                if !viewStore.voiceName.isEmpty {
                    Section(String(localized: "settings.tts.voice")) {
                        Label(viewStore.voiceName, systemImage: "person.wave.2")
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
