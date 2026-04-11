//
//  ContentView.swift
//  Luma
//
//  Created by Angel Y on 2/16/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var languageStore = LanguageStore()
    @StateObject private var sessionStore = SessionStore(restorePreviousSession: false)
    @AppStorage("tutorial_completed") private var tutorialCompleted = false

    var body: some View {
        Group {
            if sessionStore.shouldShowHome {
                if tutorialCompleted {
                    HomePageView(sessionStore: sessionStore)
                } else {
                    NavigationStack {
                        TutorialPageView {
                            tutorialCompleted = true
                        }
                    }
                }
            } else {
                AuthFlowView(sessionStore: sessionStore)
            }
        }
        .environmentObject(languageStore)
        .environment(\.locale, languageStore.currentLanguage.locale)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
