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
    @State private var httpProtocol: HttpProtocol = .http
    @State private var httpHostname: String = ""
    @State private var httpPort: String = "8096"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var conduitURL: String = "https://koji.josephloftus.com"
    @State private var error: RError?
    @State private var errorSummary: String = ""
    @State private var awaitingLogin: Bool = false
    
    @State private var appeared = false

    var body: some View {
        VStack {
            Text("Sign into Jellyfin")
                .font(StingrayFont.heroTitle)
            Spacer()
            HStack {
                Picker("Protocol", selection: $httpProtocol) {
                    ForEach(HttpProtocol.allCases, id: \.self) { availableProtocol in
                        Text(availableProtocol.rawValue).tag(availableProtocol)
                    }
                }
                .pickerStyle(.menu)
                switch httpProtocol {
                case .http:
                    TextField("Hostname", text: $httpHostname)
                    TextField("Port", text: $httpPort)
                        .keyboardType(.numberPad)
                case .https:
                    TextField("URL", text: $httpHostname)
                }
            }
            HStack {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }
            TextField("Conduit URL (optional)", text: $conduitURL)
            if let error = self.error {
                ErrorView(error: error, summary: self.errorSummary)
                    .padding(.vertical)
            }
            Spacer()
            HStack {
                ProgressView()
                    .opacity(0)
                Button("Connect") {
                    setupConnection()
                }
                .disabled(awaitingLogin)
                ProgressView()
                    .opacity(awaitingLogin ? 1 : 0)
            }
            .buttonStyle(.borderedProminent)
        }
        .glassBackground(cornerRadius: 32, padding: StingraySpacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(StingrayAnimation.fadeIn, value: appeared)
        .onAppear {
            appeared = true
            logger.debug("Attempting to set up from storage")
            guard let defaultUser = UserModel.shared.getDefaultUser() else {
                logger.debug("Failed to setup from storage, showing login screen")
                return
            }
            switch defaultUser.serviceType {
            case .Jellyfin(let userJellyfin):
                var client: ConduitClient?
                if let conduit = defaultUser.conduitURL {
                    client = ConduitClient(baseURL: conduit)
                }
                loggedIn = .loggedIn(
                    JellyfinModel(
                        userDisplayName: defaultUser.displayName,
                        userID: defaultUser.id,
                        serviceID: defaultUser.serviceID,
                        accessToken: userJellyfin.accessToken,
                        sessionID: userJellyfin.sessionID,
                        serviceURL: defaultUser.serviceURL
                    ),
                    conduitClient: client
                )
            }
        }
    }
    
    func setupConnection() {
        // Setup URL
        var url: URL?
        switch httpProtocol {
        case .http:
            url = URL(string: "http://\(httpHostname):\(httpPort)")
        case .https:
            url = URL(string: "https://\(httpHostname)")
        }
        guard let url else {
            let netError: NetworkError
            switch httpProtocol {
            case .http:
                netError = NetworkError.invalidURL("http://\(httpHostname):\(httpPort)")
                self.error = netError
                self.errorSummary = LoginView.overrideNetErrorMessage(netErr: netError, httpProtocol: .http)
            case .https:
                netError = NetworkError.invalidURL("https://\(httpHostname)")
                self.error = netError
                self.errorSummary = LoginView.overrideNetErrorMessage(netErr: netError, httpProtocol: .https)
            }
            return
        }
        
        // Setup streaming service
        Task {
            awaitingLogin = true
            do {
                let parsedConduitURL = conduitURL.isEmpty ? nil : URL(string: conduitURL)
                let streamingService = try await JellyfinModel.login(url: url, username: username, password: password, conduitURL: parsedConduitURL)
                var client: ConduitClient?
                if let conduit = parsedConduitURL {
                    client = ConduitClient(baseURL: conduit)
                }
                self.loggedIn = .loggedIn(streamingService, conduitClient: client)
            } catch let error as RError {
                self.error = AccountErrors.loginFailed(error)
                if let netErr = error.last() as? NetworkError {
                    self.errorSummary = LoginView.overrideNetErrorMessage(netErr: netErr, httpProtocol: self.httpProtocol)
                    logger.error("Error signing in: \(error.rDescription())")
                } else {
                    self.errorSummary = "An unexpected error occurred. Please make sure your login details are correct."
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
