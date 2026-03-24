//
//  KojiConfig.swift
//  Stingray
//
//  Centralized service endpoints for Koji stack.
//

import Foundation

enum KojiConfig {
    static let jellyfin  = URL(string: "http://100.98.170.115:8096")!
    static let conduit   = URL(string: "https://koji.josephloftus.com")!
    static let suri      = URL(string: "http://100.98.170.115:8100")!
    static let username  = "joseph"
    static let password  = "koji2026"
}
