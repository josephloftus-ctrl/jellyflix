//
//  AddServerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import os
import SwiftUI

private let logger = Logger(subsystem: "com.benlab.stingray", category: "login")

struct AddServerView: View {
    @Binding var loggedIn: LoginState
    @State private var error: RError?
    @State private var errorSummary: String = ""
    @State private var awaitingLogin: Bool = false

    @State private var appeared = false

    var body: some View {
        VStack {
            Text("Jellyflix")
                .font(StingrayFont.heroTitle)
            Text("Connecting to Koji...")
                .font(.subheadline)
                .foregroundStyle(StingrayColors.textSecondary)
            Spacer()
            if let error = self.error {
                ErrorView(error: error, summary: self.errorSummary)
                    .padding(.vertical)
                Button("Retry") {
                    setupConnection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(awaitingLogin)
            } else {
                ProgressView()
            }
            Spacer()
        }
        .glassBackground(cornerRadius: 32, padding: StingraySpacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(StingrayAnimation.fadeIn, value: appeared)
        .onAppear {
            appeared = true
            logger.debug("Attempting to set up from storage")
            guard let defaultUser = UserModel.shared.getDefaultUser() else {
                logger.debug("No stored user, auto-connecting")
                setupConnection()
                return
            }
            switch defaultUser.serviceType {
            case .Jellyfin(let userJellyfin):
                let client = ConduitClient(baseURL: KojiConfig.conduit)
                let suriClient = SuriClient(baseURL: KojiConfig.suri)
                loggedIn = .loggedIn(
                    JellyfinModel(
                        userDisplayName: defaultUser.displayName,
                        userID: defaultUser.id,
                        serviceID: defaultUser.serviceID,
                        accessToken: userJellyfin.accessToken,
                        sessionID: userJellyfin.sessionID,
                        serviceURL: KojiConfig.jellyfin
                    ),
                    conduitClient: client,
                    suriClient: suriClient
                )
            }
        }
    }

    func setupConnection() {
        Task {
            awaitingLogin = true
            error = nil
            do {
                let streamingService = try await JellyfinModel.login(
                    url: KojiConfig.jellyfin,
                    username: KojiConfig.username,
                    password: KojiConfig.password,
                    conduitURL: KojiConfig.conduit
                )
                let client = ConduitClient(baseURL: KojiConfig.conduit)
                let suriClient = SuriClient(baseURL: KojiConfig.suri)
                self.loggedIn = .loggedIn(streamingService, conduitClient: client, suriClient: suriClient)
            } catch let error as RError {
                self.error = AccountErrors.loginFailed(error)
                if let netErr = error.last() as? NetworkError {
                    self.errorSummary = LoginView.overrideNetErrorMessage(netErr: netErr, httpProtocol: .http)
                    logger.error("Error signing in: \(error.rDescription())")
                } else {
                    self.errorSummary = "An unexpected error occurred."
                    logger.error("Login error: \(error)")
                }
            }
            awaitingLogin = false
        }
    }
}

#Preview {
    @Previewable @State var loginState: LoginState = .loggedOut
    AddServerView(loggedIn: $loginState)
}
