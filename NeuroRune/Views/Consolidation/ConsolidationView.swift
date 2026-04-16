//
//  ConsolidationView.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 5 — Consolidate now sheet. 제안 카드 리스트 + 빈/로딩/에러 상태.
//

import SwiftUI
import ComposableArchitecture

struct ConsolidationView: View {
    let store: StoreOf<ConsolidationFeature>
    var onDismiss: () -> Void = {}

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                content(viewStore)
                    .navigationTitle(String(localized: "consolidation.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "common.done")) { onDismiss() }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                viewStore.send(.consolidateTapped)
                            } label: {
                                if viewStore.isLoading {
                                    ProgressView()
                                } else {
                                    Label(
                                        String(localized: "consolidation.runNow"),
                                        systemImage: "sparkles"
                                    )
                                }
                            }
                            .disabled(viewStore.isLoading)
                        }
                    }
                    .alert(
                        String(localized: "error.prefix"),
                        isPresented: .init(
                            get: { viewStore.error != nil },
                            set: { if !$0 { viewStore.send(.errorDismissed) } }
                        )
                    ) {
                        Button(String(localized: "common.ok")) { viewStore.send(.errorDismissed) }
                    } message: {
                        if let err = viewStore.error {
                            Text(String(localized: errorMessageKey(err)))
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func content(_ viewStore: ViewStoreOf<ConsolidationFeature>) -> some View {
        if viewStore.isLoading && viewStore.proposals.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: "consolidation.loading"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewStore.proposals.isEmpty {
            emptyState(viewStore)
        } else {
            List {
                ForEach(viewStore.proposals) { proposal in
                    ProposalCard(
                        proposal: proposal,
                        isAccepting: viewStore.acceptingId == proposal.id,
                        onAccept: { viewStore.send(.proposalAccepted(proposal.id)) },
                        onReject: { viewStore.send(.proposalRejected(proposal.id)) }
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }

    private func emptyState(_ viewStore: ViewStoreOf<ConsolidationFeature>) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            if viewStore.resultAt != nil {
                Text(String(localized: "consolidation.empty.quietMorning"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "consolidation.empty.tapToStart"))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func errorMessageKey(_ e: ConsolidationError) -> String.LocalizationValue {
        switch e {
        case .llmFailed:     return "consolidation.error.llm"
        case .invalidJSON:   return "consolidation.error.invalidJSON"
        case .emptyResponse: return "consolidation.error.empty"
        }
    }
}
