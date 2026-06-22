//
//  pullerbox_iosApp.swift
//  pullerbox-ios
//
//  Created by Yuxiang Liao on 2026/5/31.
//

import SwiftUI

@main
struct pullerbox_iosApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .preferredColorScheme(.light)
        }
    }
}
