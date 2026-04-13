//
//  PersistenceError.swift
//  NeuroRune
//

nonisolated enum PersistenceError: Error, Equatable {
    /// SwiftData 레이어의 `roleRaw` 값이 `Message.Role`로 디코딩되지 않음.
    /// 조용히 `.user`로 떨어뜨리는 대신 명시적으로 실패시킨다 (데이터 변조 방지).
    case invalidMessageRole(String)
    /// ModelContainer 초기화 실패. 디스크 풀, 마이그레이션 실패, 컨테이너 손상 등.
    /// 이 상태에서는 모든 CRUD 연산이 실패한다.
    case containerUnavailable
}
