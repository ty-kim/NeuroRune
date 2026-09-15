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
                VStack(spacing: 0) {
                    if let warning = viewStore.memoryWarning {
                        memoryWarningBanner(warning)
                    }
                    content(viewStore)
                }
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

    /// 메모리를 읽지 못했을 때의 안내. 제안이 대화만 보고 만들어졌음을 알린다.
    @ViewBuilder
    private func memoryWarningBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .accessibilityElement(children: .combine)
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
