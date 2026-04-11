//
//  LumaApp.swift
//  Luma
//
//  Created by Angel Y on 2/16/26.
//

import SwiftUI

@main
struct LumaApp: App {
    var body: some Scene {
        WindowGroup {
            AppLaunchRootView()
        }
    }
}

private struct AppLaunchRootView: View {
    @State private var isShowingLoadingView = true

    var body: some View {
        Group {
            if isShowingLoadingView {
                LoadingView {
                    isShowingLoadingView = false
                }
            } else {
                ContentView()
            }
        }
    }
}
