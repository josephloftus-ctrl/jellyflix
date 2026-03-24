//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import os
import SwiftUI

private let logger = Logger(subsystem: "com.benlab.stingray", category: "navigation")

/// Login phase of the application
enum LoginState {
    /// All users are logged out
    case loggedOut
    /// There is at least one user signed in
    case loggedIn(any StreamingServiceProtocol, conduitClient: ConduitClient? = nil, suriClient: SuriClient? = nil)
}

struct ContentView: View {
    @State var loginState: LoginState = .loggedOut
    @State var deepLinkRequest: DeepLinkRequest?
    
    var body: some View {
        Group {
            switch loginState {
            case .loggedOut:
                AddServerView(loggedIn: $loginState)
                    .padding(128)
                    .transition(.opacity)
            case .loggedIn(let streamingService, let conduitClient, let suriClient):
                DashboardView(streamingService: streamingService, conduitClient: conduitClient, suriClient: suriClient, deepLinkRequest: $deepLinkRequest, loggedIn: $loginState)
                    .onOpenURL { url in
                        handleDeepLink(url: url)
                    }
                    .transition(.opacity)
            }
        }
        .animation(StingrayAnimation.fadeIn, value: isLoggedIn)
    }

    private var isLoggedIn: Bool {
        if case .loggedIn = loginState { return true }
        return false
    }
    
    private func handleDeepLink(url: URL) {
        logger.debug("Deep link received: \(url.absoluteString, privacy: .private)")
        
        // Make sure URL scheme is good
        guard url.scheme == "stingray",
              url.host == "media" else {
            logger.warning("Invalid deep link scheme or host")
            return
        }
        
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.warning("Failed to parse URL components")
            return
        }
        
        // Get mediaID and its parent for lookup later
        let mediaID = queryItems.first(where: { $0.name == "id" })?.value
        let parentID = queryItems.first(where: { $0.name == "parentID" })?.value
        guard let mediaID = mediaID, let parentID = parentID else {
            logger.warning("Missing required parameters: mediaID or parentID")
            return
        }
        
        logger.debug("Parsed deep link - mediaID: \(mediaID, privacy: .private), parentID: \(parentID, privacy: .private)")
        
        // Create deep link request
        deepLinkRequest = DeepLinkRequest(mediaID: mediaID, parentID: parentID)
    }
}

struct DeepLinkRequest: Equatable, Hashable {
    let mediaID: String
    let parentID: String
    let id = UUID() // Ensure each request is unique
}

#Preview {
    ContentView()
}
