//
//  ClipboardState.swift
//  Perch
//

enum ClipboardState: Equatable {
    case empty
    case loaded([ClipboardItem])
}
