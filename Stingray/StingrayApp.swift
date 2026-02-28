//
//  StingrayApp.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@main
struct StingrayApp: App {
    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024, // 100 MB
            diskCapacity: 500 * 1024 * 1024 // 500 MB
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background {
                     LinearGradient(
                        colors: [StingrayColors.backgroundGradientTop, StingrayColors.backgroundGradientBottom],
                         startPoint: .top,
                         endPoint: .bottom
                     )
                }
                .ignoresSafeArea()
        }
    }
}
