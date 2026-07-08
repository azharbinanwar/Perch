//
//  ValueSlider.swift
//  Perch
//

import SwiftUI

struct ValueSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: { onChange(($0 / step).rounded() * step) }), in: range)
                .frame(width: 140)
            Text(String(format: format, value)).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
        }
    }
}
