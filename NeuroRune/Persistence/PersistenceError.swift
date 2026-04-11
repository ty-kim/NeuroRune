//
//  PersistenceError.swift
//  NeuroRune
//

nonisolated enum PersistenceError: Error, Equatable {
    /// SwiftData 레이어의 `roleRaw` 값이 `Message.Role`로 디코딩되지 않음.
    /// 조용히 `.user`로 떨어뜨리는 대신 명시적으로 실패시킨다 (데이터 변조 방지).
    case invalidMessageRole(String)
}
