//
//  OnboardingView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>
    var onComplete: () -> Void = {}

    @State private var isKeyRevealed = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)

                    Text("Anthropic API Key")
                        .font(.title2.bold())

                    Text(String(localized: "onboarding.description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Group {
                                if isKeyRevealed {
                                    TextField("sk-ant-...", text: viewStore.binding(
                                        get: \.apiKeyInput,
                                        send: OnboardingFeature.Action.apiKeyChanged
                                    ))
                                } else {
                                    SecureField("sk-ant-...", text: viewStore.binding(
                                        get: \.apiKeyInput,
                                        send: OnboardingFeature.Action.apiKeyChanged
                                    ))
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityLabel(String(localized: "a11y.onboarding.apiKeyField"))
                            .accessibilityHint(String(localized: "a11y.onboarding.apiKeyHint"))

                            Button {
                                isKeyRevealed.toggle()
                            } label: {
                                Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(String(localized: isKeyRevealed ? "a11y.onboarding.hideKey" : "a11y.onboarding.revealKey"))
                        }

                        if let error = viewStore.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        viewStore.send(.saveTapped)
                    } label: {
                        if viewStore.isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(String(localized: "onboarding.save"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewStore.isValid || viewStore.isSaving)
                    .padding(.horizontal)

                    Spacer()
                }
                .navigationTitle("NeuroRune")
                .onChange(of: viewStore.isSaving) { wasSaving, isSaving in
                    if wasSaving && !isSaving && viewStore.error == nil {
                        onComplete()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}
