//
//  LoadingView.swift
//  Luma1
//
//  Created by Codex on 4/11/26.
//

import SwiftUI

struct LoadingView: View {
    let onFinish: () -> Void
    @State private var didScheduleFinish = false

    var body: some View {
        ZStack {
            LumaPalette.backgroundTop
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 360)
                .frame(width: 230)
                .accessibilityHidden(true)
        }
        .task {
            guard didScheduleFinish == false else { return }
            didScheduleFinish = true
            try? await Task.sleep(for: .seconds(1.5))
            onFinish()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView {}
    }
}
